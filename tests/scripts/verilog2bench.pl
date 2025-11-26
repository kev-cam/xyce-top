#!/usr/bin/env perl
#
# verilog2bench.pl
#
# Convert cleaned Verilog library cells to ISCAS89 BENCH format for Atalanta ATPG
#

use strict;
use warnings;
use File::Basename;
use Getopt::Long;

my $help = 0;
my $verbose = 0;

GetOptions(
    'help|h'    => \$help,
    'verbose|v' => \$verbose,
) or die "Error in command line arguments\n";

if ($help || @ARGV == 0) {
    print_usage();
    exit($help ? 0 : 1);
}

my $verilog_file = shift @ARGV;
my $bench_file = shift @ARGV;

unless (-f $verilog_file) {
    die "Error: Verilog file not found: $verilog_file\n";
}

# Default output filename if not specified
unless ($bench_file) {
    $bench_file = $verilog_file;
    $bench_file =~ s/\.v$/.bench/;
}

print "Converting $verilog_file to $bench_file\n" if $verbose;

# Parse Verilog and generate BENCH
convert_verilog_to_bench($verilog_file, $bench_file);

print "Conversion complete: $bench_file\n" if $verbose;

exit 0;

# Subroutines

sub convert_verilog_to_bench {
    my ($vfile, $bfile) = @_;

    open(my $in_fh, '<', $vfile) or die "Cannot open $vfile: $!\n";
    open(my $out_fh, '>', $bfile) or die "Cannot create $bfile: $!\n";

    my ($module_name, @inputs, @outputs, %gates);
    my $in_module = 0;
    my $gate_count = 0;

    # Parse Verilog
    while (my $line = <$in_fh>) {
        # Skip comments and blank lines
        $line =~ s/\/\/.*$//;
        $line =~ s/\/\*.*?\*\///g;
        next if $line =~ /^\s*$/;

        # Extract module name
        if ($line =~ /module\s+(\w+)/) {
            $module_name = $1;
            $in_module = 1;
            next;
        }

        next unless $in_module;

        # Extract inputs
        if ($line =~ /\binput\s+(?:\w+\s+)?(\w+)/) {
            push @inputs, $1;
        }

        # Extract outputs
        if ($line =~ /\boutput\s+(?:\w+\s+)?(\w+)/) {
            push @outputs, $1;
        }

        # Parse gate instantiations
        # Format: gatetype inst_name ( .port(signal), ... );
        if ($line =~ /^\s*sky130_\w+__(\w+)_\d+\s+\w+\s*\(/) {
            my $gate_type = uc($1);  # Convert to uppercase
            my $gate_line = $line;

            # Continue reading if statement spans multiple lines
            while ($gate_line !~ /\);/ && (my $next = <$in_fh>)) {
                $gate_line .= $next;
            }

            my $gate_info = parse_gate_instantiation($gate_line, $gate_type);
            if ($gate_info) {
                push @{$gates{$gate_info->{output}}}, $gate_info;
                $gate_count++;
            }
        }

        last if $line =~ /endmodule/;
    }

    close($in_fh);

    # Write BENCH format
    print $out_fh "# $module_name\n";
    print $out_fh "# " . scalar(@inputs) . " inputs\n";
    print $out_fh "# " . scalar(@outputs) . " outputs\n";
    print $out_fh "# $gate_count gates\n";
    print $out_fh "\n";

    # Write inputs
    foreach my $input (@inputs) {
        print $out_fh "INPUT($input)\n";
    }
    print $out_fh "\n";

    # Write outputs
    foreach my $output (@outputs) {
        print $out_fh "OUTPUT($output)\n";
    }
    print $out_fh "\n";

    # Write gates
    foreach my $output (sort keys %gates) {
        foreach my $gate (@{$gates{$output}}) {
            write_bench_gate($out_fh, $gate);
        }
    }

    close($out_fh);
}

sub parse_gate_instantiation {
    my ($line, $gate_type) = @_;

    my %port_map;
    my ($output, @inputs);

    # Extract port connections: .port(signal)
    while ($line =~ /\.(\w+)\s*\(\s*(\w+)\s*\)/g) {
        my ($port, $signal) = ($1, $2);
        $port_map{$port} = $signal;
    }

    # Determine output (usually Y, X, or Q)
    foreach my $out_port (qw(Y X Q ZN)) {
        if (exists $port_map{$out_port}) {
            $output = $port_map{$out_port};
            delete $port_map{$out_port};
            last;
        }
    }

    return unless $output;

    # Remaining ports are inputs
    @inputs = sort values %port_map;

    # Map gate type to BENCH format
    my $bench_type = map_gate_type($gate_type);

    return {
        type   => $bench_type,
        output => $output,
        inputs => \@inputs,
    };
}

sub map_gate_type {
    my ($gate_type) = @_;

    # Map SkyWater gate types to BENCH gate types
    return 'NOT'  if $gate_type =~ /^INV/;
    return 'BUF'  if $gate_type =~ /^BUF/;
    return 'AND'  if $gate_type =~ /^AND/;
    return 'NAND' if $gate_type =~ /^NAND/;
    return 'OR'   if $gate_type =~ /^OR/ && $gate_type !~ /^NOR/;
    return 'NOR'  if $gate_type =~ /^NOR/;
    return 'XOR'  if $gate_type =~ /^XOR/ && $gate_type !~ /^XNOR/;
    return 'XNOR' if $gate_type =~ /^XNOR/;

    # Default to BUF for unknown types
    return 'BUF';
}

sub write_bench_gate {
    my ($fh, $gate) = @_;

    my $type = $gate->{type};
    my $output = $gate->{output};
    my @inputs = @{$gate->{inputs}};

    if ($type eq 'NOT') {
        print $fh "$output = NOT($inputs[0])\n";
    }
    elsif ($type eq 'BUF') {
        print $fh "$output = BUFF($inputs[0])\n";
    }
    else {
        # Multi-input gates
        my $input_list = join(', ', @inputs);
        print $fh "$output = $type($input_list)\n";
    }
}

sub print_usage {
    print <<'USAGE';
Usage: verilog2bench.pl [OPTIONS] verilog_file [bench_file]

Convert Verilog library cells to ISCAS89 BENCH format for Atalanta ATPG

Arguments:
  verilog_file    Input Verilog file (should be cleaned, no power pins)
  bench_file      Output BENCH file (optional, defaults to input.bench)

Options:
  --verbose, -v   Verbose output
  --help, -h      Show this help message

Example:
  verilog2bench.pl sky130_fd_sc_hd__inv_1.v
  verilog2bench.pl input.v output.bench

USAGE
}
