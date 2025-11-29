#!/usr/bin/env perl
#
# generate_test.pl - Generate standalone Verilator test from Verilog module
#
# Parses Verilog to extract ports and generates appropriate test pattern
#

use strict;
use warnings;
use Getopt::Long;

my $module_name = '';
my $verilog_file = '';
my $help = 0;

GetOptions(
    'module|m=s'  => \$module_name,
    'verilog|v=s' => \$verilog_file,
    'help|h'      => \$help,
) or die "Error in command line arguments\n";

if ($help || !$module_name) {
    print_usage();
    exit 0;
}

# If verilog file not specified, try to find it
if (!$verilog_file) {
    $verilog_file = "$module_name.v";
    die "Error: Verilog file $verilog_file not found\n" unless -f $verilog_file;
}

# Parse the Verilog file to extract port information
my ($inputs_ref, $outputs_ref) = parse_verilog($verilog_file, $module_name);
my @inputs = @$inputs_ref;
my @outputs = @$outputs_ref;

print "Module: $module_name\n";
print "Inputs: ", join(", ", @inputs), "\n";
print "Outputs: ", join(", ", @outputs), "\n";

# Generate test file
my $test_file = "test_${module_name}.cpp";
generate_test($test_file, $module_name, \@inputs, \@outputs);

print "Generated: $test_file\n";

sub parse_verilog {
    my ($file, $module) = @_;
    my @inputs;
    my @outputs;

    open(my $fh, '<', $file) or die "Cannot open $file: $!\n";

    my $in_module = 0;

    while (my $line = <$fh>) {
        # Remove comments
        $line =~ s/\/\/.*$//;
        $line =~ s/\/\*.*?\*\///g;

        if ($line =~ /^\s*module\s+$module\s*(\(|;)/) {
            $in_module = 1;
        }
        elsif ($in_module) {
            if ($line =~ /^\s*input\s+(?:wire\s+)?(?:\[.*?\]\s+)?(\w+)/) {
                my $port = $1;
                # Skip power pins
                push @inputs, $port unless $port =~ /^(VDD|VPWR|VCC|VSS|VGND|GND|VNB|VPB)$/i;
            }
            elsif ($line =~ /^\s*output\s+(?:wire\s+)?(?:reg\s+)?(?:\[.*?\]\s+)?(\w+)/) {
                push @outputs, $1;
            }
            elsif ($line =~ /^\s*endmodule/) {
                last;
            }
        }
    }

    close($fh);

    return (\@inputs, \@outputs);
}

sub generate_test {
    my ($file, $module, $inputs_ref, $outputs_ref) = @_;
    my @inputs = @$inputs_ref;
    my @outputs = @$outputs_ref;
    my $verilator_class = "V$module";

    open(my $fh, '>', $file) or die "Cannot create $file: $!\n";

    # Header
    print $fh <<EOF;
#include <iostream>
#include <iomanip>
#include "$verilator_class.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    $verilator_class* top = new $verilator_class;

    double time_ns = 0.0;
    double time_step = 1.0;  // 1ns per step

    std::cout << "# Testing $module" << std::endl;
    std::cout << "# time(ns)";
EOF

    # Output column headers
    for my $in (@inputs) {
        print $fh "\n    std::cout << \" $in\";";
    }
    for my $out (@outputs) {
        print $fh "\n    std::cout << \" $out\";";
    }
    print $fh "\n    std::cout << std::endl;\n\n";

    # Generate test pattern based on number of inputs
    my $num_inputs = scalar(@inputs);

    if ($num_inputs == 0) {
        # No inputs - just run once
        print $fh <<EOF;
    top->eval();
    std::cout << std::fixed << std::setprecision(2) << time_ns;
EOF
        for my $out (@outputs) {
            print $fh " << \" \" << (int)top->$out";
        }
        print $fh " << std::endl;\n";
    }
    elsif ($num_inputs == 1) {
        # Single input - toggle pattern
        my $in = $inputs[0];
        print $fh <<EOF;
    // Toggle input pattern
    for (int i = 0; i < 10; i++) {
        top->$in = (i % 2);
        top->eval();
        std::cout << std::fixed << std::setprecision(2) << time_ns;
        std::cout << " " << (int)top->$in;
EOF
        for my $out (@outputs) {
            print $fh "        std::cout << \" \" << (int)top->$out;\n";
        }
        print $fh <<EOF;
        std::cout << std::endl;
        time_ns += time_step;
    }
EOF
    }
    elsif ($num_inputs <= 4) {
        # Small number of inputs - test all combinations
        print $fh "    // Test all input combinations\n";

        # Generate nested loops for all combinations
        for (my $i = 0; $i < $num_inputs; $i++) {
            my $indent = "    " x ($i + 1);
            print $fh "${indent}for (int $inputs[$i] = 0; $inputs[$i] <= 1; $inputs[$i]++) {\n";
        }

        my $indent = "    " x ($num_inputs + 1);

        # Set inputs
        for my $in (@inputs) {
            print $fh "${indent}top->$in = $in;\n";
        }
        print $fh "${indent}top->eval();\n";
        print $fh "${indent}std::cout << std::fixed << std::setprecision(2) << time_ns;\n";

        # Output values
        for my $in (@inputs) {
            print $fh "${indent}std::cout << \" \" << (int)top->$in;\n";
        }
        for my $out (@outputs) {
            print $fh "${indent}std::cout << \" \" << (int)top->$out;\n";
        }
        print $fh "${indent}std::cout << std::endl;\n";
        print $fh "${indent}time_ns += time_step;\n";

        # Close loops
        for (my $i = $num_inputs - 1; $i >= 0; $i--) {
            my $indent = "    " x ($i + 1);
            print $fh "${indent}}\n";
        }
    }
    else {
        # Many inputs - use counter-based pattern
        print $fh "    // Counter-based test pattern\n";
        print $fh "    for (int i = 0; i < 16; i++) {\n";

        for (my $i = 0; $i < $num_inputs; $i++) {
            print $fh "        top->$inputs[$i] = (i >> $i) & 1;\n";
        }

        print $fh "        top->eval();\n";
        print $fh "        std::cout << std::fixed << std::setprecision(2) << time_ns;\n";

        for my $in (@inputs) {
            print $fh "        std::cout << \" \" << (int)top->$in;\n";
        }
        for my $out (@outputs) {
            print $fh "        std::cout << \" \" << (int)top->$out;\n";
        }
        print $fh "        std::cout << std::endl;\n";
        print $fh "        time_ns += time_step;\n";
        print $fh "    }\n";
    }

    # Cleanup
    print $fh <<EOF;

    delete top;
    return 0;
}
EOF

    close($fh);
}

sub print_usage {
    print <<'USAGE';
Usage: generate_test.pl -m MODULE_NAME [OPTIONS]

Generate standalone Verilator test from Verilog module

Options:
  -m, --module MODULE   Module name (required)
  -v, --verilog FILE    Verilog source file (default: MODULE.v)
  -h, --help            Show this help message

Example:
  generate_test.pl -m nand2 -v nand2.v

This generates test_nand2.cpp with appropriate test pattern based on
the number of inputs.

USAGE
}
