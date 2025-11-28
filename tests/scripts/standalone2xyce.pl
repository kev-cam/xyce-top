#!/usr/bin/env perl
#
# standalone2xyce.pl
#
# Convert standalone Verilator test output to Xyce circuit with VPWL sources
#

use strict;
use warnings;
use Getopt::Long;

my $help = 0;
my $module = '';
my $output_file = '';

GetOptions(
    'help|h'      => \$help,
    'module|m=s'  => \$module,
    'output|o=s'  => \$output_file,
) or die "Error in command line arguments\n";

if ($help || @ARGV == 0) {
    print_usage();
    exit($help ? 0 : 1);
}

my $input_file = shift @ARGV;

unless (-f $input_file) {
    die "Error: Input file not found: $input_file\n";
}

# Parse the test output
my ($test_module, $signals_ref, $data_ref) = parse_test_output($input_file);
my @signals = @$signals_ref;
my @data_points = @$data_ref;

# Use module name from file if not specified
$module = $test_module unless $module;

# Default output filename
$output_file = "${module}_replay.cir" unless $output_file;

print "Converting $input_file to Xyce circuit...\n";
print "Module: $module\n";
print "Signals: " . join(", ", @signals) . "\n";
print "Data points: " . scalar(@data_points) . "\n";

# Generate Xyce circuit
generate_xyce_circuit($output_file, $module, \@signals, \@data_points);

print "Created: $output_file\n";

exit 0;

# Subroutines

sub parse_test_output {
    my ($file) = @_;

    open(my $fh, '<', $file) or die "Cannot open $file: $!\n";

    my ($module_name, @signal_names, @data);

    while (my $line = <$fh>) {
        chomp $line;

        # Skip empty lines
        next if $line =~ /^\s*$/;

        # Extract module name from comment
        if ($line =~ /^#\s*Testing\s+(\w+)/) {
            $module_name = $1;
            next;
        }

        # Extract signal names from header
        if ($line =~ /^#\s*time.*?\s+(.+)$/) {
            my $signals = $1;
            @signal_names = split(/\s+/, $signals);
            next;
        }

        # Skip other comments
        next if $line =~ /^#/;

        # Parse data line: time value1 value2 ...
        if ($line =~ /^([\d.eE+-]+)\s+(.+)$/) {
            my ($time, $values) = ($1, $2);
            my @vals = split(/\s+/, $values);
            push @data, {
                time => $time,
                values => \@vals,
            };
        }
    }

    close($fh);

    return ($module_name, \@signal_names, \@data);
}

sub parse_subcircuit_ports {
    my ($module_name) = @_;

    # Try to find the subcircuit .cir file
    my @search_paths = (
        "${module_name}.cir",
        "../verilator-test/${module_name}.cir",
        "verilator-test/${module_name}.cir",
        "./${module_name}.cir",
    );

    my $subckt_file;
    foreach my $path (@search_paths) {
        if (-f $path) {
            $subckt_file = $path;
            last;
        }
    }

    # If no subcircuit file found, return empty
    return ([], {}) unless $subckt_file;

    open(my $fh, '<', $subckt_file) or return ([], {});

    my @subckt_ports;
    my %power_pins;

    while (my $line = <$fh>) {
        chomp $line;

        # Look for .SUBCKT definition
        if ($line =~ /^\s*\.SUBCKT\s+\S+\s+(.+)$/i) {
            my $ports_str = $1;
            @subckt_ports = split(/\s+/, $ports_str);

            # Identify power supply pins
            foreach my $port (@subckt_ports) {
                if ($port =~ /^(VDD|VPWR|VCC|VPP)$/i) {
                    $power_pins{$port} = 'supply';  # Positive supply
                } elsif ($port =~ /^(VSS|VGND|GND|VEE|VNB|VPB)$/i) {
                    $power_pins{$port} = 'ground';  # Ground/substrate
                }
            }
            last;
        }
    }

    close($fh);

    return (\@subckt_ports, \%power_pins);
}

sub parse_verilog_module {
    my ($module_name) = @_;

    # Try to find the Verilog file
    my @search_paths = (
        "${module_name}.v",
        "../verilator-test/${module_name}.v",
        "verilator-test/${module_name}.v",
        "./${module_name}.v",
    );

    my $verilog_file;
    foreach my $path (@search_paths) {
        if (-f $path) {
            $verilog_file = $path;
            last;
        }
    }

    unless ($verilog_file) {
        die "Error: Cannot find Verilog file for module $module_name\n";
    }

    open(my $fh, '<', $verilog_file) or die "Cannot open $verilog_file: $!\n";

    my %inputs;
    my %outputs;
    my @port_order;  # Track port order from Verilog
    my $in_module = 0;

    while (my $line = <$fh>) {
        chomp $line;

        # Look for module declaration
        if ($line =~ /^\s*module\s+$module_name\s*\(/) {
            $in_module = 1;
        }

        next unless $in_module;

        # Parse input declarations
        if ($line =~ /^\s*input\s+(?:wire\s+)?(\w+)/) {
            $inputs{$1} = 1;
            push @port_order, $1;
        }

        # Parse output declarations
        if ($line =~ /^\s*output\s+(?:wire\s+)?(\w+)/) {
            $outputs{$1} = 1;
            push @port_order, $1;
        }

        # End of module port list
        last if $line =~ /\)\s*;/;
    }

    close($fh);

    return (\%inputs, \%outputs, \@port_order);
}

sub generate_xyce_circuit {
    my ($file, $module, $signals_ref, $data_ref) = @_;
    my @signals = @$signals_ref;
    my @data = @$data_ref;

    open(my $fh, '>', $file) or die "Cannot create $file: $!\n";

    print $fh "* Xyce circuit generated from standalone Verilator test\n";
    print $fh "* Module: $module\n";
    print $fh "* Generated by standalone2xyce.pl\n";
    print $fh "\n";

    # Title
    print $fh ".TITLE Replay of $module test\n\n";

    # Parse subcircuit to check for power supply pins
    my ($subckt_ports_ref, $power_pins_ref) = parse_subcircuit_ports($module);
    my @subckt_ports = @$subckt_ports_ref;
    my %power_pins = %$power_pins_ref;

    # Parse Verilog to determine input/output ports
    my ($inputs_ref, $outputs_ref, $port_order_ref) = parse_verilog_module($module);
    my %input_ports = %$inputs_ref;
    my %output_ports = %$outputs_ref;
    my @verilog_port_order = @$port_order_ref;

    # Classify signals based on Verilog port directions
    my @inputs = grep { exists $input_ports{$_} } @signals;
    my @outputs = grep { exists $output_ports{$_} } @signals;

    # Create a mapping from signal name to index in data
    my %signal_index;
    for (my $i = 0; $i < @signals; $i++) {
        $signal_index{$signals[$i]} = $i;
    }

    # Create mapping from test signal names to subcircuit port names (case-insensitive)
    my %signal_to_port;
    if (@subckt_ports) {
        # Build case-insensitive mapping
        my %port_lc_map;
        foreach my $port (@subckt_ports) {
            $port_lc_map{lc($port)} = $port unless exists $power_pins{$port};
        }

        # Map test signals to subcircuit ports
        foreach my $sig (@signals) {
            if (exists $port_lc_map{lc($sig)}) {
                $signal_to_port{$sig} = $port_lc_map{lc($sig)};
            }
        }
    }

    # Generate PWL sources for input signals (drive circuit directly)
    foreach my $signal (@inputs) {
        my $idx = $signal_index{$signal};
        # Use subcircuit port name if available, otherwise use test signal name
        my $net_name = $signal_to_port{$signal} || $signal;

        # Build PWL time-value pairs
        my @pwl_pairs;
        foreach my $dp (@data) {
            my $time_s = $dp->{time} * 1e-9;  # Convert ns to seconds
            my $value = $dp->{values}[$idx];
            push @pwl_pairs, "${time_s} ${value}";
        }

        my $pwl_data = join(" ", @pwl_pairs);
        print $fh "V${net_name} ${net_name} 0 PWL( $pwl_data )\n";
    }

    print $fh "\n";

    # Generate reference PWL sources for output signals (with _ref suffix)
    foreach my $signal (@outputs) {
        my $idx = $signal_index{$signal};
        # Use subcircuit port name if available, otherwise use test signal name
        my $net_name = $signal_to_port{$signal} || $signal;

        # Build PWL time-value pairs
        my @pwl_pairs;
        foreach my $dp (@data) {
            my $time_s = $dp->{time} * 1e-9;  # Convert ns to seconds
            my $value = $dp->{values}[$idx];
            push @pwl_pairs, "${time_s} ${value}";
        }

        my $pwl_data = join(" ", @pwl_pairs);
        print $fh "V${net_name}_ref ${net_name}_ref 0 PWL( $pwl_data )\n";
    }

    print $fh "\n";

    # Add power supply voltage sources if subcircuit needs them
    if (keys %power_pins) {
        print $fh "* Power supplies\n";
        foreach my $pin (sort keys %power_pins) {
            if ($power_pins{$pin} eq 'supply') {
                # Positive supply (VDD, VPWR, etc.) - use 3.3V for SkyWater, 5V for others
                my $voltage = ($pin =~ /VPWR|VDD/i) ? "3.3" : "5.0";
                print $fh "V${pin} ${pin} 0 DC ${voltage}V\n";
            } elsif ($power_pins{$pin} eq 'ground') {
                # Ground/substrate pins - connect to 0V
                print $fh "V${pin} ${pin} 0 DC 0V\n";
            }
        }
        print $fh "\n";
    }

    # Add dummy loads for output signals (wire resistance + capacitance)
    if (@outputs) {
        print $fh "* Output loads\n";
        foreach my $signal (@outputs) {
            my $net_name = $signal_to_port{$signal} || $signal;
            # Wire resistance (100 ohms) and load capacitance (10 fF)
            print $fh "R${net_name} ${net_name} 0 100\n";
            print $fh "C${net_name} ${net_name} 0 1e-14\n";
        }
        print $fh "\n";
    }

    # Include the subcircuit (assuming it's in a separate file)
    print $fh "* Include the $module subcircuit\n";
    print $fh ".INCLUDE ${module}.cir\n";
    print $fh "\n";

    # Instantiate the subcircuit
    # Use subcircuit port order if available, otherwise use Verilog port order
    my @instance_nets;
    if (@subckt_ports) {
        # Map subcircuit ports to actual net names
        foreach my $port (@subckt_ports) {
            if (exists $power_pins{$port}) {
                # Power pin - use the pin name as net
                push @instance_nets, $port;
            } else {
                # Signal port - use the subcircuit's port name as net
                push @instance_nets, $port;
            }
        }
    } else {
        # Fall back to Verilog port order
        @instance_nets = @verilog_port_order;
    }

    my $net_list = join(" ", @instance_nets);
    print $fh "* Instantiate the device under test\n";
    print $fh "X1 $net_list $module\n";
    print $fh "\n";

    # Analysis
    my $end_time = $data[-1]->{time} * 1e-9;
    my $time_step = ($data[1]->{time} - $data[0]->{time}) * 1e-9;

    print $fh "* Transient analysis\n";
    print $fh ".TRAN $time_step $end_time\n";
    print $fh "\n";

    # Print statements - show both circuit outputs and references
    print $fh "* Output\n";
    foreach my $signal (@inputs) {
        my $net_name = $signal_to_port{$signal} || $signal;
        print $fh ".PRINT TRAN V($net_name)\n";
    }
    foreach my $signal (@outputs) {
        my $net_name = $signal_to_port{$signal} || $signal;
        print $fh ".PRINT TRAN V($net_name) V(${net_name}_ref)\n";
    }
    print $fh "\n";

    print $fh ".END\n";

    close($fh);
}

sub print_usage {
    print <<'USAGE';
Usage: standalone2xyce.pl [OPTIONS] input_file

Convert standalone Verilator test output to Xyce circuit with VPWL sources

Arguments:
  input_file      Output from standalone Verilator test

Options:
  --module, -m NAME   Module name (default: extracted from input)
  --output, -o FILE   Output .cir file (default: MODULE_replay.cir)
  --help, -h          Show this help message

Example:
  ./test_standalone > test.out
  standalone2xyce.pl test.out -o replay.cir

This creates a Xyce circuit that replays the test pattern using VPWL sources.

USAGE
}
