#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use File::Basename;

# verilog2xyce.pl - Generate Xyce wrapper for Verilog modules
# Automatically creates C++ bridge code and SPICE netlist for Verilator-based
# analog-digital co-simulation with Xyce

my $help = 0;
my $build = 0;
my $test_netlist = 0;
my $output_prefix = "";

GetOptions(
    'help|h'      => \$help,
    'build|b'     => \$build,
    'netlist|n'   => \$test_netlist,
    'output|o=s'  => \$output_prefix,
) or die "Error in command line arguments\n";

if ($help || @ARGV == 0) {
    print_usage();
    exit(0);
}

my $verilog_file = $ARGV[0];
die "Error: File '$verilog_file' not found\n" unless -f $verilog_file;

# Parse the Verilog module
my $module = parse_verilog($verilog_file);

# Set output prefix based on module name if not specified
$output_prefix = lc($module->{name}) unless $output_prefix;

# Generate C++ bridge code
my $cpp_file = "${output_prefix}_xyce_bridge.cpp";
generate_cpp_bridge($module, $cpp_file);
print "Generated C++ bridge: $cpp_file\n";

# Generate test netlist if requested
if ($test_netlist) {
    my $netlist_file = "${output_prefix}_test.cir";
    generate_test_netlist($module, $netlist_file, $output_prefix);
    print "Generated test netlist: $netlist_file\n";
}

# Build shared library if requested
if ($build) {
    build_shared_library($module, $output_prefix, $cpp_file);
}

print "Done!\n";

#------------------------------------------------------------------------------
# Parse Verilog module to extract ports
#------------------------------------------------------------------------------
sub parse_verilog {
    my ($file) = @_;

    open(my $fh, '<', $file) or die "Cannot open $file: $!\n";
    my $content = do { local $/; <$fh> };
    close($fh);

    # Remove comments
    $content =~ s/\/\/.*$//gm;  # Single line comments
    $content =~ s/\/\*.*?\*\///gs;  # Multi-line comments

    # Extract module declaration
    my ($module_name, $port_list) = $content =~ /module\s+(\w+)\s*\((.*?)\);/s
        or die "Error: Could not find module declaration in $file\n";

    my @inputs;
    my @outputs;
    my @inouts;

    # First try to parse ANSI-style ports (inside module header)
    while ($port_list =~ /\b(input|output|inout)\s+(?:wire|reg)?\s*(\[.*?\])?\s*(\w+)/g) {
        my $direction = $1;
        my $width = $2 || "";
        my $name = $3;
        $name =~ s/^\s+|\s+$//g;

        if ($direction eq 'input') {
            push @inputs, {name => $name, width => $width};
        } elsif ($direction eq 'output') {
            push @outputs, {name => $name, width => $width};
        } elsif ($direction eq 'inout') {
            push @inouts, {name => $name, width => $width};
        }
    }

    # If no ports found in header, try non-ANSI style (port declarations in body)
    if (@inputs == 0 && @outputs == 0 && @inouts == 0) {
        while ($content =~ /\b(input|output|inout)\s+(?:wire|reg)?\s*(\[.*?\])?\s*(\w+(?:\s*,\s*\w+)*)/g) {
            my $direction = $1;
            my $width = $2 || "";
            my $names = $3;

            # Handle multiple signals in one declaration
            foreach my $name (split /\s*,\s*/, $names) {
                $name =~ s/^\s+|\s+$//g;

                if ($direction eq 'input') {
                    push @inputs, {name => $name, width => $width};
                } elsif ($direction eq 'output') {
                    push @outputs, {name => $name, width => $width};
                } elsif ($direction eq 'inout') {
                    push @inouts, {name => $name, width => $width};
                }
            }
        }
    }

    die "Error: No inputs found in module $module_name\n" unless @inputs;
    die "Error: No outputs found in module $module_name\n" unless @outputs;

    return {
        name => $module_name,
        inputs => \@inputs,
        outputs => \@outputs,
        inouts => \@inouts,
    };
}

#------------------------------------------------------------------------------
# Generate C++ bridge code
#------------------------------------------------------------------------------
sub generate_cpp_bridge {
    my ($module, $output_file) = @_;

    my $mod_name = $module->{name};
    my $class_name = ucfirst($mod_name) . "Wrapper";
    my $verilator_class = "V${mod_name}";

    my $num_inputs = scalar @{$module->{inputs}};

    open(my $fh, '>', $output_file) or die "Cannot create $output_file: $!\n";

    print $fh <<'HEADER';
#include <iostream>
#include <vector>
#include <cmath>
#include <ctype.h>
#include <strings.h>
HEADER

    print $fh "#include \"obj_dir/${verilator_class}.h\"\n";
    print $fh <<'HEADER2';
#include "../xbridge.h"
#include "../gates.h"

HEADER2

    # Forward declarations
    print $fh "// Forward declarations\n";
    print $fh "void ${class_name}InCross(PwlHandler *pwlh, double skew, double Vbegin, double Vend);\n";
    print $fh "void ${class_name}SetVdd(PwlHandler *pwlh, double skew, double Vbegin, double Vend);\n\n";

    # Generate class definition
    print $fh "// Verilator wrapper for $mod_name module\n";
    print $fh "class $class_name : public GateX<$num_inputs> {\n";
    print $fh "private:\n";
    print $fh "    ${verilator_class}* verilator_model;\n";
    print $fh "    double vth_high;  // Threshold for logic high\n";
    print $fh "    double vth_low;   // Threshold for logic low\n\n";

    print $fh "public:\n";
    print $fh "    ${class_name}() : verilator_model(nullptr) {\n";
    print $fh "        verilator_model = new ${verilator_class};\n";
    print $fh "        vth_high = 1.5;  // 1.5V threshold\n";
    print $fh "        vth_low = 1.5;\n";
    print $fh "    }\n\n";

    print $fh "    ~${class_name}() {\n";
    print $fh "        if (verilator_model) {\n";
    print $fh "            verilator_model->final();\n";
    print $fh "            delete verilator_model;\n";
    print $fh "        }\n";
    print $fh "    }\n\n";

    # Generate input setters
    for (my $i = 0; $i < $num_inputs; $i++) {
        my $input = $module->{inputs}[$i];
        print $fh "    inline void set${\(ucfirst($input->{name}))}(GatePwlHandler *h) { in[$i] = h; }\n";
        print $fh "    inline GatePwlHandler *${\(ucfirst($input->{name}))}() const { return in[$i]; }\n\n";
    }

    # Generate Finished() method
    print $fh "    bool Finished() {\n";
    print $fh "        bool ret = false;\n";
    print $fh "        if (";
    for (my $i = 0; $i < $num_inputs; $i++) {
        print $fh "NULL != in[$i] &&\n            ";
    }
    print $fh "NULL != vdd   &&\n";
    print $fh "            NULL != out   && out->ready()) {\n";
    print $fh "            setParams();\n";
    print $fh "            ret = true;\n";
    print $fh "        }\n";
    print $fh "        return ret;\n";
    print $fh "    }\n\n";

    # Generate Eval() method
    print $fh "    void Eval(double now) {\n";
    print $fh "        double v_dd = vdd->startV();\n\n";
    print $fh "        if (abs(v_dd - vdd_last) >= v_tol) {\n";
    print $fh "            vdd_last = v_dd;\n";
    for (my $i = 0; $i < $num_inputs; $i++) {
        print $fh "            in[$i]->setTimes(now, now);\n";
    }
    print $fh "            lgc_pend |= LGC_UNKNOWN;\n\n";
    print $fh "            // Trigger cross handler for first input\n";
    print $fh "            if (v_dd > v_min && in[0]->startV() > (v_dd/2)) {\n";
    print $fh "                ${class_name}InCross(in[0], 0.0, 0.0, v_dd);\n";
    print $fh "            } else {\n";
    print $fh "                ${class_name}InCross(in[0], 0.0, v_dd, 0.0);\n";
    print $fh "            }\n";
    print $fh "        }\n";
    for (my $i = 0; $i < $num_inputs; $i++) {
        print $fh "        in[$i]->setProbe(t_tol/2.0);\n";
    }
    print $fh "    }\n\n";

    # Generate EvaluateModel() method
    print $fh "    // Evaluate the Verilator model\n";
    print $fh "    double EvaluateModel(";
    for (my $i = 0; $i < $num_inputs; $i++) {
        print $fh "double v_" . $module->{inputs}[$i]{name};
        print $fh ", " unless $i == $num_inputs - 1;
    }
    print $fh ", double v_dd) {\n";
    print $fh "        // Convert analog to digital\n";

    for (my $i = 0; $i < $num_inputs; $i++) {
        my $input = $module->{inputs}[$i];
        print $fh "        uint8_t $input->{name}_digital = (v_$input->{name} > vth_high) ? 1 : 0;\n";
    }

    print $fh "\n        // Run Verilator model\n";
    for (my $i = 0; $i < $num_inputs; $i++) {
        my $input = $module->{inputs}[$i];
        print $fh "        verilator_model->$input->{name} = $input->{name}_digital;\n";
    }
    print $fh "        verilator_model->eval();\n";

    # Assume single output for now
    my $output = $module->{outputs}[0]{name};
    print $fh "        uint8_t ${output}_digital = verilator_model->$output;\n\n";
    print $fh "        // Convert digital back to analog\n";
    print $fh "        return ${output}_digital ? v_dd : 0.0;\n";
    print $fh "    }\n";
    print $fh "};\n\n";

    # Generate global vector
    print $fh "std::vector<${class_name} *> ${class_name}s;\n\n";

    # Generate Gate::setParams()
    print $fh "void Gate::setParams() {\n";
    print $fh "    v_min  = out->getParam(\"Vmin\", v_min);\n";
    print $fh "    t_tol  = out->getParam(\"Ttol\", t_tol);\n";
    print $fh "    v_tol  = out->getParam(\"Vtol\", v_tol);\n";
    print $fh "    delay  = out->getParam(\"Delay\", v_tol);\n";
    print $fh "    rise_t = out->getParam(\"RiseT\", v_tol);\n";
    print $fh "    fall_t = out->getParam(\"FallT\", v_tol);\n";
    print $fh "}\n\n";

    # Generate cross handlers (before extern "C")
    print $fh "void ${class_name}SetVdd(PwlHandler *pwlh, double skew, double Vbegin, double Vend) {\n";
    print $fh "    GatePwlHandler *gpwlh = (GatePwlHandler *)pwlh;\n";
    print $fh "    ${class_name} *gate = (${class_name} *)gpwlh->gate;\n\n";
    print $fh "    if (gate->" . ucfirst($module->{inputs}[0]{name}) . "()->setTrig(Vbegin/2.0)) {\n";
    print $fh "        gate->Eval(gate->Vdd()->endT());\n";
    print $fh "    }\n";
    print $fh "}\n\n";

    print $fh "void ${class_name}InCross(PwlHandler *pwlh, double skew, double Vbegin, double Vend) {\n";
    print $fh "    GatePwlHandler *gpwlh = (GatePwlHandler *)pwlh;\n";
    print $fh "    ${class_name} &gate = (*(${class_name} *)gpwlh->gate);\n\n";
    print $fh "    GatePwlHandler &out(*gate.Out());\n";
    print $fh "    GatePwlHandler &vdd(*gate.Vdd());\n";
    print $fh "    tTVVEC &TV(*out.getTV());\n\n";
    print $fh "    double dt = gate.Delay() - skew;\n";
    print $fh "    if (dt < 0.0) dt = 0.0;\n\n";
    print $fh "    double t = out.endT() + dt;\n";
    print $fh "    double v_dd = vdd.startV();\n\n";
    print $fh "    // Use Verilator model to determine output\n";
    print $fh "    double v_out = gate.EvaluateModel(";
    for (my $i = 0; $i < $num_inputs; $i++) {
        print $fh "gate." . ucfirst($module->{inputs}[$i]{name}) . "()->startV()";
        print $fh ", " unless $i == $num_inputs - 1;
    }
    print $fh ", v_dd);\n\n";
    print $fh "    // Add transition\n";
    print $fh "    TV.push_back(std::pair<double,double>(t, v_out));\n";
    print $fh "    out.setProbe(0.0);\n";
    print $fh "}\n\n";

    print $fh "extern \"C\" {\n\n";

    # Generate bridge functions
    print $fh "int GatePwlBridgeOut(PWLinDynData *XyceSrc, void *MyData, int op, void *data) {\n";
    print $fh "    ${class_name} *gate = (${class_name} *)MyData;\n";
    print $fh "    return PwlBridge(XyceSrc, gate->Out(), op, data);\n";
    print $fh "}\n\n";

    for (my $i = 0; $i < $num_inputs; $i++) {
        my $input = $module->{inputs}[$i];
        my $func_name = ucfirst($input->{name});
        print $fh "int GatePwlBridge${func_name}(PWLinDynData *XyceSrc, void *MyData, int op, void *data) {\n";
        print $fh "    ${class_name} *gate = (${class_name} *)MyData;\n";
        print $fh "    return PwlBridge(XyceSrc, gate->$func_name(), op, data);\n";
        print $fh "}\n\n";
    }

    print $fh "int GatePwlBridgeVdd(PWLinDynData *XyceSrc, void *MyData, int op, void *data) {\n";
    print $fh "    ${class_name} *gate = (${class_name} *)MyData;\n";
    print $fh "    return PwlBridge(XyceSrc, gate->Vdd(), op, data);\n";
    print $fh "}\n\n";

    # Generate attachment function
    print $fh "// Attachment function for Xyce\n";
    print $fh "BridgeFn Attach${class_name}(PWLinDynData *XyceSrc, void **MyData, const char *args) {\n";
    print $fh "    BridgeFn bFn = PwlBridge;\n";
    print $fh "    std::vector<${class_name} *>::iterator ii = ${class_name}s.begin();\n";
    print $fh "    bool new_gate = false;\n";
    print $fh "    ${class_name} *gate, *check = NULL;\n\n";
    print $fh "    if (ii == ${class_name}s.end()) { // first time only\n";
    print $fh "        gate = new ${class_name}();\n";
    print $fh "        PwlHandler::setFns(MyData);\n";
    print $fh "        ${class_name}s.insert(${class_name}s.begin(), gate);\n";
    print $fh "    } else {\n";
    print $fh "        gate = *ii; // try adding to last\n";
    print $fh "    }\n\n";

    print $fh "    if (0 == strncasecmp(args, \"output\", 6)) {\n";
    print $fh "        if (new_gate = (NULL != gate->Out())) {\n";
    print $fh "            check = gate;\n";
    print $fh "            gate   = new ${class_name}();\n";
    print $fh "        }\n";
    print $fh "        while (*args && *args++ != ',');\n";
    print $fh "        gate->setOut(new GatePwlHandler(XyceSrc, gate, args));\n";
    print $fh "        bFn = GatePwlBridgeOut;\n";
    print $fh "    }\n";
    print $fh "    else if (0 == strncasecmp(args, \"vdd\", 3)) {\n";
    print $fh "        if (new_gate = (NULL != gate->Vdd())) {\n";
    print $fh "            check = gate;\n";
    print $fh "            gate   = new ${class_name}();\n";
    print $fh "        }\n";
    print $fh "        while (*args && *args++ != ',');\n";
    print $fh "        gate->setVdd(new GatePwlHandler(XyceSrc, gate, args, TRIG_MODE(TRIG_ALWAYS), ${class_name}SetVdd));\n";
    print $fh "        bFn = GatePwlBridgeVdd;\n";
    print $fh "    }\n";

    # Generate input handlers
    for (my $i = 0; $i < $num_inputs; $i++) {
        my $input = $module->{inputs}[$i];
        my $func_name = ucfirst($input->{name});
        print $fh "    else if (0 == strncasecmp(args, \"$input->{name}\", " . length($input->{name}) . ")) {\n";
        print $fh "        if (new_gate = (NULL != gate->$func_name())) {\n";
        print $fh "            check = gate;\n";
        print $fh "            gate   = new ${class_name}();\n";
        print $fh "        }\n";
        print $fh "        while (*args && !(isdigit(*args) || ',' == *args)) {\n";
        print $fh "            args++;\n";
        print $fh "        }\n";
        print $fh "        while (*args && *args++ != ',');\n";
        print $fh "        gate->set$func_name(new GatePwlHandler(XyceSrc, gate, args, TRIG_MODE(TRIG_NEVER), ${class_name}InCross));\n";
        print $fh "        bFn = GatePwlBridge${func_name};\n";
        print $fh "    }\n";
    }

    print $fh "\n    if (NULL != check) { // Trying to build two at once?\n";
    print $fh "        if (check->Finished()) {\n";
    print $fh "            assert(*ii == check);\n";
    print $fh "            ${class_name}s.erase(ii);\n";
    print $fh "        }\n";
    print $fh "    }\n\n";
    print $fh "    if (new_gate) {\n";
    print $fh "        ${class_name}s.insert(${class_name}s.begin(), gate);\n";
    print $fh "    }\n";
    print $fh "    else {\n";
    print $fh "        if (gate->Finished()) {\n";
    print $fh "            assert(*ii == gate);\n";
    print $fh "            ${class_name}s.erase(ii);\n";
    print $fh "        }\n";
    print $fh "    }\n\n";
    print $fh "    *MyData = gate;\n";
    print $fh "    return bFn;\n";
    print $fh "}\n\n";

    print $fh "} // extern \"C\"\n";

    close($fh);
}

#------------------------------------------------------------------------------
# Generate test SPICE netlist
#------------------------------------------------------------------------------
sub generate_test_netlist {
    my ($module, $output_file, $prefix) = @_;

    my $mod_name = $module->{name};
    my $class_name = ucfirst($mod_name) . "Wrapper";
    my $lib_name = "./${prefix}.so";
    my $attach_fn = "Attach${class_name}";

    open(my $fh, '>', $output_file) or die "Cannot create $output_file: $!\n";

    print $fh "* Test netlist for $mod_name Verilator wrapper\n";
    print $fh "* Auto-generated by verilog2xyce.pl\n\n";

    print $fh ".title $mod_name test\n\n";

    # Power supply
    print $fh "* Power supply\n";
    print $fh "VDD VDD 0 DC 3.1V\n";
    print $fh "RVDD VDD 0 1MEG\n\n";

    # Generate test inputs
    print $fh "* Test inputs\n";
    my $input_num = 1;
    foreach my $input (@{$module->{inputs}}) {
        my $node = uc($input->{name});
        print $fh "VIN$input_num $node 0 PULSE(0V 3V 2ns 100ps 100ps 8ns 20ns)\n";
        $input_num++;
    }
    print $fh "\n";

    # Output node
    my $output_node = uc($module->{outputs}[0]{name});
    print $fh "* Output load\n";
    print $fh "COUT $output_node 0 1pF\n";
    print $fh "ROUT $output_node 0 1MEG\n\n";

    # PWL sources using external code
    print $fh "* Verilator-based device using external code loading\n";
    print $fh "VPWL_OUT DRV 0 PWL FILE \"code:$lib_name:$attach_fn:output,Vtol=1e-3,Ttol=1e-13,Delay=5e-12,RiseT=3e-12,FallT=2e-12\"\n";

    $input_num = 1;
    foreach my $input (@{$module->{inputs}}) {
        my $node = uc($input->{name});
        print $fh "IPWL_$input->{name} $node 0 PWL FILE \"code:$lib_name:$attach_fn:$input->{name}\"\n";
        $input_num++;
    }
    print $fh "IPWL_VDD VDD 0 PWL FILE \"code:$lib_name:$attach_fn:vdd\"\n\n";

    # Analysis
    print $fh "* Analysis\n";
    print $fh ".tran 10ps 40ns\n";
    print $fh ".print tran V(VDD) ";
    foreach my $input (@{$module->{inputs}}) {
        print $fh "V(" . uc($input->{name}) . ") ";
    }
    print $fh "V($output_node)\n";
    print $fh ".end\n";

    close($fh);
}

#------------------------------------------------------------------------------
# Build shared library
#------------------------------------------------------------------------------
sub build_shared_library {
    my ($module, $prefix, $cpp_file) = @_;

    my $mod_name = $module->{name};
    my $verilator_class = "V${mod_name}";
    my $so_name = "${prefix}.so";

    print "Building Verilator model...\n";

    # Run Verilator
    my $verilog_file = "${mod_name}.v";
    unless (-f $verilog_file) {
        die "Error: Verilog file $verilog_file not found\n";
    }

    system("verilator --cc $verilog_file -CFLAGS \"-fPIC\"") == 0
        or die "Verilator compilation failed\n";

    # Build Verilator library
    system("make -C obj_dir -f ${verilator_class}.mk") == 0
        or die "Verilator library build failed\n";

    print "Building shared library...\n";

    # Compile bridge code
    my $cmd = "g++ -shared -fPIC -o $so_name $cpp_file ../xbridge.C " .
              "/usr/share/verilator/include/verilated.cpp " .
              "/usr/share/verilator/include/verilated_threads.cpp " .
              "obj_dir/${verilator_class}__ALL.a " .
              "-I/usr/local/xyce_patched/include " .
              "-I/home/user/trilinos-14.4-install/include " .
              "-I/usr/share/verilator/include -I. -std=c++11";

    system($cmd) == 0 or die "Shared library build failed\n";

    print "Built: $so_name\n";
    my $size = -s $so_name;
    printf "Size: %.1f KB\n", $size / 1024;
}

#------------------------------------------------------------------------------
# Print usage information
#------------------------------------------------------------------------------
sub print_usage {
    print <<'USAGE';
verilog2xyce.pl - Generate Xyce wrapper for Verilog modules

Usage:
    verilog2xyce.pl [options] <verilog_file>

Options:
    -h, --help           Show this help message
    -b, --build          Run Verilator and build shared library
    -n, --netlist        Generate test SPICE netlist
    -o, --output PREFIX  Output file prefix (default: module name)

Description:
    Generates C++ bridge code to wrap a Verilog module for use with Xyce
    circuit simulator. The wrapper uses Verilator to compile Verilog to C++
    and provides the glue code for Xyce's external code loading mechanism.

Examples:
    # Generate C++ bridge only
    ./verilog2xyce.pl my_module.v

    # Generate bridge and test netlist
    ./verilog2xyce.pl --netlist my_module.v

    # Generate everything and build shared library
    ./verilog2xyce.pl --build --netlist my_module.v

    # Custom output prefix
    ./verilog2xyce.pl -o custom_name -b -n my_module.v

Output:
    <prefix>_xyce_bridge.cpp   - C++ wrapper code
    <prefix>_test.cir          - Test SPICE netlist (with -n)
    <prefix>.so                - Shared library (with -b)

Requirements:
    - Verilator (5.x or later)
    - g++ with C++11 support
    - Xyce with external code loading patches
    - xbridge.h and gates.h in parent directory

USAGE
}
