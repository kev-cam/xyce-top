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
my $debug = 0;

GetOptions(
    'help|h'    => \$help,
    'debug|d'   => \$debug,
    'verbose|v' => \$verbose,
) or die "Error in command line arguments\n";

if ($help || @ARGV == 0) {
    print_usage();
    exit($help ? 0 : 1);
}

my $verilog_file = shift @ARGV;
my $bench_file = shift @ARGV;

my %gate;
my %module_ports;  # Cache for module port lists

foreach my $gt ("and","or","xor","buf","not","nand","nor","xnor") {
    $gate{$gt} = 1;
}

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

    my ($module_name, %signals, @gates);
    my $in_module = 0;

    # Parse Verilog to extract module name, inputs, outputs, and gates
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

        # Extract outputs first (they take precedence)
        if ($line =~ /^\s*output\s+(?:wire\s+)?(?:reg\s+)?(\w+)/) {
            $signals{$1} = 'output';
        }
        # Extract inputs (only if not already marked as output)
        elsif ($line =~ /^\s*input\s+(?:wire\s+)?(\w+)/) {
            $signals{$1} = 'input' unless exists $signals{$1};
        }
        # Parse instantance gate instantiations 
        elsif ($line =~ /^\s*((\w|_|\\|\$)+)\s+\w+\s*\(\s*(.*)(\)(;)|\,$)/) {

            my ($gate_type, $ports) = (uc($1), $3);

	    if ($5 ne ";") { # continues
		my $linex;
		$ports .= ",";
		while ($linex = <$in_fh>) {
		    chomp $linex;
		    $linex=~ s/\)\s*(;)//;
		    $ports .= $linex;
		    last if ($1 eq ";");
		}
		my %bind;
		my @named = split(/\s*,\s*/,$ports);
		foreach my $p (@named) {
		    if ($p =~ /\.((\w)+)\(\s*(\S+)\s*\)/) {
			$bind{$1} = $3;
		    } else {
			die "Port binding not understood - $p";
		    }
		}
		if ($gate{$gate_type}) {
		    $ports = $bind{Y};
		    my $c = 'A';
		    while ($bind{$c}) {
			$ports .= ",".$bind{$c};
			$c++;
		    }
		} else {
		    # Look up port order from module file
		    my $port_list = get_module_ports($gate_type);
		    if ($port_list && @$port_list) {
			# Build ports string using the defined port order
			my @ordered_ports;
			foreach my $port (@$port_list) {
			    if (exists $bind{$port}) {
				push @ordered_ports, $bind{$port};
			    } else {
				warn "Warning: Port $port not found in bindings for $gate_type\n";
			    }
			}
			$ports = join(",", @ordered_ports);
		    } else {
			die "NIY: Cannot determine port order for module $gate_type\n";
		    }
		}
	    }

            # Parse ports: first is output, rest are inputs
            my @port_list = split(/\s*,\s*/, $ports);
            next unless @port_list >= 2;

            my $out = shift @port_list;  # First port is output
            my @ins = @port_list;         # Rest are inputs

            push @gates, {
                type => $gate_type,
                output => $out,
                inputs => \@ins,
            };
        }
	elsif ($debug) {
	    print "???: $line\n";
	}

        last if $line =~ /endmodule/;
    }

    close($in_fh);

    # Separate signals into inputs and outputs
    my @inputs = sort grep { $signals{$_} eq 'input' } keys %signals;
    my @outputs = sort grep { $signals{$_} eq 'output' } keys %signals;

    # Write BENCH format header
    print $out_fh "# $module_name\n";
    print $out_fh "# " . scalar(@inputs) . " inputs\n";
    print $out_fh "# " . scalar(@outputs) . " outputs\n";
    print $out_fh "# " . scalar(@gates) . " gates\n";
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

    # Write gates
    foreach my $gate (@gates) {
        write_bench_gate($out_fh, $gate);
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

sub get_module_ports {
    my ($module_name) = @_;

    # Return cached result if available
    return $module_ports{$module_name} if exists $module_ports{$module_name};

    # Look for module file (try lowercase version)
    my $module_file = lc($module_name) . ".v";

    unless (-f $module_file) {
        warn "Warning: Module file not found: $module_file\n";
        return undef;
    }

    # Parse module file to extract port list
    open(my $mfh, '<', $module_file) or do {
        warn "Warning: Cannot open $module_file: $!\n";
        return undef;
    };

    my @port_order;
    my $in_module = 0;

    while (my $line = <$mfh>) {
        # Skip comments
        $line =~ s/\/\/.*$//;
        $line =~ s/\/\*.*?\*\///g;
        next if $line =~ /^\s*$/;

        # Look for module declaration
        if ($line =~ /module\s+\w+\s*\(/) {
            $in_module = 1;
        }

        next unless $in_module;

        # Extract port declarations in order
        if ($line =~ /^\s*(?:input|output|inout)\s+(?:wire\s+|reg\s+)?(?:\[.*?\]\s+)?(\w+)/) {
            push @port_order, $1;
        }

        last if $line =~ /endmodule/;
    }

    close($mfh);

    # Cache and return the port list
    $module_ports{$module_name} = \@port_order;
    return \@port_order;
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
