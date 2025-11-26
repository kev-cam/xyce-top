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

    my ($module_name, @inputs, @outputs);
    my $in_module = 0;

    # Parse Verilog to extract module name, inputs, and outputs
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

        # Extract inputs (handle multiple formats)
        if ($line =~ /\binput\s+(?:wire\s+)?(\w+)/) {
            push @inputs, $1 unless grep { $_ eq $1 } @inputs;
        }

        # Extract outputs (handle multiple formats)
        if ($line =~ /\boutput\s+(?:wire\s+)?(?:reg\s+)?(\w+)/) {
            push @outputs, $1 unless grep { $_ eq $1 } @outputs;
        }

        last if $line =~ /endmodule/;
    }

    close($in_fh);

    # Determine gate type from module name
    # SkyWater format: sky130_fd_sc_hd__GATETYPE_STRENGTH
    my $gate_type = 'BUF';  # Default
    if ($module_name =~ /sky130_\w+_\w+_\w+__(\w+)_\d+/) {
        $gate_type = uc($1);
    } elsif ($module_name =~ /__(\w+)_/) {
        $gate_type = uc($1);
    } elsif ($module_name =~ /(\w+)_\d+$/) {
        $gate_type = uc($1);
    }

    # Map to BENCH gate type
    my $bench_type = map_gate_type($gate_type);

    # Write BENCH format header
    print $out_fh "# $module_name\n";
    print $out_fh "# " . scalar(@inputs) . " inputs\n";
    print $out_fh "# " . scalar(@outputs) . " outputs\n";
    print $out_fh "# 1 gate ($bench_type)\n";
    print $out_fh "\n";

    # Write inputs
    foreach my $input (@inputs) {
        print $out_fh "INPUT($input)\n";
    }
    print $out_fh "\n" if @inputs;

    # Write outputs
    foreach my $output (@outputs) {
        print $out_fh "OUTPUT($output)\n";
    }
    print $out_fh "\n" if @outputs;

    # Write the gate equation
    # The module itself IS the gate
    if (@outputs && @inputs) {
        my $output = $outputs[0];  # Primary output

        if ($bench_type eq 'NOT' || $bench_type eq 'BUF') {
            # Single input gates
            my $op = ($bench_type eq 'NOT') ? 'NOT' : 'BUFF';
            print $out_fh "$output = $op($inputs[0])\n";
        } else {
            # Multi-input gates
            my $input_list = join(', ', @inputs);
            print $out_fh "$output = $bench_type($input_list)\n";
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
