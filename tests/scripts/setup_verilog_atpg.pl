#!/usr/bin/env perl
#
# setup_verilog_atpg.pl
#
# Setup ATPG testing environment for Verilog library cells.
#
# This script traverses a directory hierarchy (e.g., skywater-pdk-libs-sky130_fd_sc_hdll),
# finds directories containing Verilog library cells (.v files), creates 'xatpg'
# subdirectories, and generates Makefiles to run FAN_ATPG tests.
#

use strict;
use warnings;
use File::Find;
use File::Path qw(make_path);
use File::Spec;
use File::Basename;
use Getopt::Long;
use Cwd 'abs_path';

# Configuration
my $dry_run = 0;
my $verbose = 0;
my @exclude_dirs = qw(xatpg .git __pycache__ CVS .svn);
my $help = 0;
my $test = 0;
my $filter = "behavioral";
my $exclude = "pp";
my $output;

# Parse command line options
GetOptions(
    'dry-run'     => \$dry_run,
    'verbose|v'   => \$verbose,
    'test|t=s'    => \$test,
    'output|o=s'  => \$output,
    'exclude=s@'  => \@exclude_dirs,
    'help|h'      => \$help,
) or die "Error in command line arguments\n";

if ($help || (@ARGV == 0 && ! $test)) {
    print_usage();
    exit($help ? 0 : 1);
}

if ($test) {
    my $verilog = $test;
    $verilog =~ s=.*/==;
    my $stem = $verilog;
    $stem =~ s/\.v//;
    my $mdt = $stem.".mdt";
    if (! $output) {
	$output = "$stem.fan";
    }
    open(FANF,">$output");
    while ( ! -f $mdt) {
	if ($mdt =~ /(.*)\.(\w+)\./) {
	    print STDERR "Discarded $2\n";
	    $mdt = $1.".mdt";
	    next;
	}
	last;
    }
    die "Missing an MDT file ($mdt)!" unless ( -f $mdt );
    my $fanv = $verbose ? "--verbose" : "";
    print FANF "read_lib $mdt\n";
    print FANF "read_netlist $fanv $stem.v\n";
    print FANF "build_circuit --frame 1\n";
    print FANF "set_fault_type saf\n";
    print FANF "add_fault -a\n";
    print FANF "set_static_compression on\n";
    print FANF "set_X-Fill on\n";
    print FANF "run_atpg\n";
    print FANF "write_pattern $stem-saf.pat\n";
    print FANF "exit\n";
    exit 0;
}

our $skip_dir = "_";
foreach my $d (@exclude_dirs) {
    $skip_dir .= "|$d";
}
$skip_dir =~ s=.=/(=;
$skip_dir .= ")(/|\$)";

my $self     = abs_path($0);
my $self_dir = dirname($self);

my $target_dir = shift @ARGV;

# Validate target directory
unless (-e $target_dir) {
    die "Error: Target directory does not exist: $target_dir\n";
}

unless (-d $target_dir) {
    die "Error: Target is not a directory: $target_dir\n";
}

$target_dir = abs_path($target_dir);

# Print header
print "=" x 80, "\n";
print "Verilog ATPG Setup Script (Perl)\n";
print "=" x 80, "\n";
print "Target directory: $target_dir\n";
print "Dry run: ", ($dry_run ? "True" : "False"), "\n";
print "Excluded directories: ", join(", ", @exclude_dirs), "\n";
print "=" x 80, "\n";

# Find all directories with Verilog files
print "\nSearching for Verilog files...\n";
our %verilog_dirs;
find_verilog_directories($target_dir);
unless (keys %verilog_dirs) {
    print "\nNo Verilog files found in $target_dir\n";
    exit 0;
}

my $dir_count = scalar keys %verilog_dirs;
print "\nFound $dir_count ", ($dir_count == 1 ? "directory" : "directories"),
      " containing Verilog files\n";

# Setup ATPG for each directory
my $success_count = 0;
foreach my $verilog_dir (keys %verilog_dirs) {
    if (setup_atpg_directory($verilog_dir, $dry_run)) {
        $success_count++;
    }
}

# Print summary
print "\n", "=" x 80, "\n";
print "Summary\n";
print "=" x 80, "\n";
print "Directories processed: $success_count/$dir_count\n";

if ($dry_run) {
    print "\n[DRY RUN] No changes were made. Run without --dry-run to apply changes.\n";
} else {
    print "\nSetup complete! ATPG directories and Makefiles have been created.\n";
    print "\nTo run tests in any xatpg directory:\n";
    print "  cd <directory>/xatpg\n";
    print "  make test\n";
}

print "=" x 80, "\n";

exit($success_count == $dir_count ? 0 : 1);

# Subroutines

sub find_verilog_directories {
    my ($root_path) = @_;

    my $wanted = sub {
        my $file = $_;
	
        # Look for .v files
        if (-f $file && $file =~ /$filter\.v$/) {

	    # Skip excluded directories
	    my $dir = $File::Find::dir;
	    return if ($dir =~ /$skip_dir/);
        
	    if (defined ($_ = $verilog_dirs{$dir})) {
		$verilog_dirs{$dir} = $_.",$file";
	    } else {
		$verilog_dirs{$dir} = $file;
	    }
        }
    };

    find($wanted, $root_path);
}

sub setup_atpg_directory {
    my ($verilog_dir, $dry_run) = @_;

    my @verilog_files = split(/,/,$verilog_dirs{$verilog_dir});

    return 0 unless @verilog_files;

    my $xatpg_dir = File::Spec->catdir($verilog_dir, "xatpg");

    print "\nProcessing: $verilog_dir\n";
    print "  Found ", scalar(@verilog_files), " Verilog file(s)\n";

    if ($dry_run) {
        print "  [DRY RUN] Would create: $xatpg_dir\n";
        print "  [DRY RUN] Would generate Makefile for ", scalar(@verilog_files), " files\n";
        return 1;
    }

    # Create xatpg subdirectory
    unless (-d $xatpg_dir) {
        eval { make_path($xatpg_dir) };
        if ($@) {
            warn "  Error creating directory $xatpg_dir: $@\n";
            return 0;
        }
    }
    print "  Created directory: $xatpg_dir\n";

    # Create Makefile
    eval { create_atpg_makefile($xatpg_dir, \@verilog_files, $verilog_dir) };
    if ($@) {
        warn "  Error creating Makefile: $@\n";
        return 0;
    }

    # Create cleaned Verilog files (no power pins, no preprocessor directives)
    eval { write_cleaned_verilog($xatpg_dir, \@verilog_files, $verilog_dir) };
    if ($@) {
        warn "  Error creating cleaned Verilog files: $@\n";
        return 0;
    }

    # Create .mdt files for each Verilog module
    eval { create_mdt_files($xatpg_dir, \@verilog_files, $verilog_dir) };
    if ($@) {
        warn "  Error creating .mdt files: $@\n";
        return 0;
    }

    # Create README
    eval { create_atpg_readme($xatpg_dir, $verilog_dir, scalar(@verilog_files)) };
    if ($@) {
        warn "  Error creating README: $@\n";
        return 0;
    }

    return 1;
}

sub create_atpg_makefile {
    my ($xatpg_dir, $verilog_files_ref, $parent_dir) = @_;
    my @verilog_files = @$verilog_files_ref;

    my @stems = map { my $s = $_; $s =~ s/\.v$//; $s } @verilog_files;

    my $makefile_path = File::Spec->catfile($xatpg_dir, "Makefile");

    open(my $fh, '>', $makefile_path) or die "Cannot create $makefile_path: $!\n";

    print $fh "# Makefile for ATPG testing (FAN_ATPG and Atalanta)\n";
    print $fh "# Auto-generated for directory: $parent_dir\n";
    print $fh "# Generated by setup_verilog_atpg.pl\n";
    print $fh "\n";
    print $fh "# Configuration\n";
    print $fh "VERILOG_DIR = ..\n";
    print $fh "FAN_ATPG = fan_atpg\n";
    print $fh "SETUP_ATPG = $self\n";
    print $fh "ATALANTA = atalanta\n";
    print $fh "VER2BENCH = $self_dir/verilog2bench.pl\n";
    print $fh "VERILOG_FILES = ", join(" ", @verilog_files), "\n";
    print $fh "BENCH_FILES = ", join(" ", map { "$_.bench" } @stems), "\n";
    print $fh "\n";
    print $fh "# Test targets\n";
    print $fh "FAN_TARGETS = ", join(" ", map { "$_.fan-log" } @stems), "\n";
    print $fh "ATALANTA_TARGETS = ", join(" ", map { "$_.atalanta" } @stems), "\n";
    print $fh "REPORT_FILES = ", join(" ", map { "$_.rpt \$stem.atalanta.rpt" } @stems), "\n";
    print $fh "\n";
    print $fh "# Default target\n";
    print $fh ".PHONY: all clean help test fan atalanta\n";
    print $fh "\n";
    print $fh "all: help\n";
    print $fh "\n";
    print $fh "# Run FAN_ATPG tests\n";
    print $fh "fan: \$(FAN_TARGETS)\n";
    print $fh "\t\@echo \"All FAN_ATPG tests completed\"\n";
    print $fh "\n";
    print $fh "# Run Atalanta tests\n";
    print $fh "atalanta: \$(ATALANTA_TARGETS)\n";
    print $fh "\t\@echo \"All Atalanta tests completed\"\n";
    print $fh "\n";
    print $fh "# Run both ATPG tools\n";
    print $fh "test: fan atalanta\n";
    print $fh "\t\@echo \"All ATPG tests completed\"\n";
    print $fh "\n";
    print $fh "# Convert Verilog to BENCH format for Atalanta\n";
    print $fh "%.bench: %.v\n";
    print $fh "\t\@echo \"Converting \$< to BENCH format...\"\n";
    print $fh "\t\@\$(VER2BENCH) \$< \$@ || true\n";
    print $fh "\n";
    print $fh "# Pattern rules for FAN_ATPG\n";
    print $fh "%.fan-log: %.v\n";
    print $fh "\t\@echo \"Running FAN_ATPG on \$<\"\n";
    print $fh "\t\$(SETUP_ATPG) -test \$< -o \$(patsubst %-log,%,\$\@)\n";
    print $fh "\t\$(FAN_ATPG) -f \$(patsubst %-log,%,\$\@) </dev/null || true\n";
    print $fh "\t\@touch \$@\n";
    print $fh "\n";
    print $fh "# Pattern rules for Atalanta (uses BENCH format)\n";
    print $fh "%.atalanta: %.bench\n";
    print $fh "\t\@echo \"Running Atalanta on \$<\"\n";
    print $fh "\t\@\$(ATALANTA) -t \$*.atalanta.pat \$< > \$*.atalanta.rpt 2>&1 || true\n";
    print $fh "\t\@touch \$@\n";
    print $fh "\n";
    print $fh "# Individual FAN_ATPG targets\n";

    for (my $i = 0; $i < @stems; $i++) {
        my $stem = $stems[$i];
        my $file = $verilog_files[$i];
        print $fh "\n";
        print $fh "$stem.test: \$(VERILOG_DIR)/$file\n";
        print $fh "\t\@echo \"Testing $file...\"\n";
        print $fh "\t\@\$(SETUP_ATPG) -test \$(VERILOG_DIR)/$file -o $stem.fan\n";
        print $fh "\t\@\$(FAN_ATPG) -f $stem.fan 2>&1 </dev/null | tee $stem.log || true\n";
    }

    print $fh "\n# Individual Atalanta targets\n";

    for (my $i = 0; $i < @stems; $i++) {
        my $stem = $stems[$i];
        print $fh "\n";
        print $fh "$stem.atalanta: $stem.bench\n";
        print $fh "\t\@echo \"Atalanta: Testing $stem.bench...\"\n";
        print $fh "\t\@\$(ATALANTA) -t $stem.atalanta.pat  $stem.bench > $stem.atalanta.rpt 2>&1 || true\n";
        print $fh "\t\@touch \$@\n";
    }

    print $fh "\n";
    print $fh "# Clean generated files\n";
    print $fh "clean:\n";
    print $fh "\trm -f \$(FAN_TARGETS) \$(ATALANTA_TARGETS) \$(BENCH_FILES) *.rpt *.log *.atpg *.patterns\n";
    print $fh "\n";
    print $fh "# Show help\n";
    print $fh "help:\n";
    print $fh "\t\@echo \"ATPG Makefile for Verilog library cells\"\n";
    print $fh "\t\@echo \"\"\n";
    print $fh "\t\@echo \"Targets:\"\n";
    print $fh "\t\@echo \"  fan       - Run all FAN_ATPG tests\"\n";
    print $fh "\t\@echo \"  atalanta  - Run all Atalanta tests\"\n";
    print $fh "\t\@echo \"  test      - Run both FAN_ATPG and Atalanta tests\"\n";
    print $fh "\t\@echo \"  clean     - Remove generated test files\"\n";
    print $fh "\t\@echo \"  help      - Show this help message (default)\"\n";
    print $fh "\t\@echo \"\"\n";
    print $fh "\t\@echo \"Individual FAN_ATPG tests:\"\n";

    foreach my $stem (@stems) {
        print $fh "\t\@echo \"  $stem.fan\"\n";
    }

    print $fh "\t\@echo \"\"\n";
    print $fh "\t\@echo \"Individual Atalanta tests:\"\n";

    foreach my $stem (@stems) {
        print $fh "\t\@echo \"  $stem.atalanta\"\n";
    }

    print $fh "\n";
    print $fh "\t\@echo \"\"\n";
    print $fh "\t\@echo \"Verilog files (cleaned - no power pins):\"\n";

    foreach my $file (@verilog_files) {
        print $fh "\t\@echo \"  $file\"\n";
    }

    print $fh "\n";

    close($fh);

    print "  Created Makefile: $makefile_path\n";
}

sub create_atpg_readme {
    my ($xatpg_dir, $parent_dir, $verilog_count) = @_;

    my $readme_path = File::Spec->catfile($xatpg_dir, "README.md");

    open(my $fh, '>', $readme_path) or die "Cannot create $readme_path: $!\n";

    print $fh "# FAN_ATPG Test Directory\n\n";
    print $fh "This directory contains ATPG (Automatic Test Pattern Generation) tests\n";
    print $fh "for the Verilog library cells in: $parent_dir\n\n";
    print $fh "## Contents\n\n";
    print $fh "- **Makefile**: Build file for running FAN_ATPG tests\n";
    print $fh "- **Verilog files**: $verilog_count library cell(s) found in parent directory\n\n";
    print $fh "## Usage\n\n";
    print $fh "To run all ATPG tests:\n";
    print $fh "```bash\n";
    print $fh "make test\n";
    print $fh "```\n\n";
    print $fh "To run a specific test:\n";
    print $fh "```bash\n";
    print $fh "make <cellname>.test\n";
    print $fh "```\n\n";
    print $fh "To clean generated files:\n";
    print $fh "```bash\n";
    print $fh "make clean\n";
    print $fh "```\n\n";
    print $fh "To see all available targets:\n";
    print $fh "```bash\n";
    print $fh "make help\n";
    print $fh "```\n\n";
    print $fh "## Generated by\n\n";
    print $fh "setup_verilog_atpg.pl script from xyce-top/tests\n\n";

    close($fh);

    print "  Created README: $readme_path\n";
}

sub write_cleaned_verilog {
    my ($xatpg_dir, $verilog_files_ref, $parent_dir) = @_;
    my @verilog_files = @$verilog_files_ref;

    # Power and substrate pins to exclude
    my %exclude_pins = (
        'VPWR' => 1,
        'VGND' => 1,
        'VPB'  => 1,
        'VNB'  => 1,
    );

    my $verilog_count = 0;

    foreach my $vfile (@verilog_files) {
        my $vpath = File::Spec->catfile($parent_dir, $vfile);
        my $out_path = File::Spec->catfile($xatpg_dir, $vfile);

        open(my $in_fh, '<', $vpath) or do {
            warn "Cannot open $vpath: $!\n";
            next;
        };

        open(my $out_fh, '>', $out_path) or do {
            warn "Cannot create $out_path: $!\n";
            close($in_fh);
            next;
        };

        print $out_fh "// Cleaned Verilog (power pins and preprocessor directives removed)\n";
        print $out_fh "// Auto-generated by setup_verilog_atpg.pl\n";
        print $out_fh "// Original: $vpath\n\n";

        my $in_port_list = 0;
        my $port_buffer = "";

        while (my $line = <$in_fh>) {
            # Skip preprocessor directives (lines starting with `)
            next if $line =~ /^\s*`/;

            # Track if we're in a port list
            if ($line =~ /module\s+\w+\s*\(/) {
                $in_port_list = 1;
                $port_buffer = $line;
                next;
            }

            # If we're in a port list, accumulate lines until we find the closing )
            if ($in_port_list) {
                $port_buffer .= $line;
                if ($line =~ /\);/) {
                    # Process the complete port list
                    my $cleaned_ports = clean_port_list($port_buffer, \%exclude_pins);
                    print $out_fh $cleaned_ports;
                    $in_port_list = 0;
                    $port_buffer = "";
                }
                next;
            }

            # Skip supply declarations (supply0/supply1 for power/ground)
            next if $line =~ /^\s*supply[01]\s/;

            # Filter out power/body pin declarations in the module body
            if ($line =~ /^\s*(input|output|inout)\s/) {
                my $cleaned_line = $line;
                # Remove power/body pins from declaration
                foreach my $pin (keys %exclude_pins) {
                    $cleaned_line =~ s/,?\s*\b$pin\b\s*,?//g;
                }
                # Skip line if it's now empty (only had power pins)
                next if $cleaned_line =~ /^\s*(input|output|inout)\s*[,;]*\s*$/;
                # Clean up any leftover commas
                $cleaned_line =~ s/,\s*,/,/g;
                $cleaned_line =~ s/,\s*;/;/g;
                print $out_fh $cleaned_line;
            } else {
                # Pass through other lines unchanged
                print $out_fh $line;
            }
        }

        close($in_fh);
        close($out_fh);
        $verilog_count++;
    }

    print "  Created $verilog_count cleaned Verilog file(s)\n" if $verilog_count > 0;
}

sub clean_port_list {
    my ($port_text, $exclude_ref) = @_;

    # Remove power/body pins from port list
    foreach my $pin (keys %$exclude_ref) {
        # Remove pin from port list (handles comma before or after)
        $port_text =~ s/,\s*\b$pin\b\s*//g;   # ,VPWR
        $port_text =~ s/\b$pin\b\s*,\s*//g;   # VPWR,
        $port_text =~ s/\(\s*\b$pin\b\s*\)/\(\)/g;  # (VPWR) -> ()
    }

    # Clean up any double commas or trailing commas
    $port_text =~ s/,\s*,/,/g;
    $port_text =~ s/,\s*\)/\)/g;

    return $port_text;
}

sub create_mdt_files {
    my ($xatpg_dir, $verilog_files_ref, $parent_dir) = @_;
    my @verilog_files = @$verilog_files_ref;

    my $mdt_count = 0;

    foreach my $vfile (@verilog_files) {
        my $vpath = File::Spec->catfile($parent_dir, $vfile);

        # Parse Verilog file to extract module info
        my ($module_name, $inputs_ref, $outputs_ref, $gate_type) = parse_verilog_module($vpath);

        next unless $module_name;  # Skip if can't parse

        # Create .mdt file
        my $mdt_file = File::Spec->catfile($xatpg_dir, "$module_name.mdt");

        open(my $fh, '>', $mdt_file) or die "Cannot create $mdt_file: $!\n";

        print $fh "// Auto-generated MDT file for $module_name\n";
        print $fh "// Generated by setup_verilog_atpg.pl\n";
        print $fh "// Gate type: $gate_type\n\n";

        # Generate model based on gate type
        generate_mdt_model($fh, $module_name, $inputs_ref, $outputs_ref, $gate_type);

        close($fh);
        $mdt_count++;
    }

    print "  Created $mdt_count .mdt file(s)\n" if $mdt_count > 0;
}

sub parse_verilog_module {
    my ($vfile) = @_;

    open(my $fh, '<', $vfile) or return ();

    my ($module_name, @inputs, @outputs, $gate_type);
    my $in_module = 0;

    # Power and substrate pins to exclude (not logic signals)
    my %exclude_pins = (
        'VPWR' => 1,  # Power supply
        'VGND' => 1,  # Ground
        'VPB'  => 1,  # P-well/substrate bias
        'VNB'  => 1,  # N-well bias
    );

    while (my $line = <$fh>) {
        # Remove comments
        $line =~ s/\/\/.*$//;
        $line =~ s/\/\*.*?\*\///g;

        # Extract module name
        if ($line =~ /module\s+(\w+)/) {
            $module_name = $1;
            $in_module = 1;

            # Infer gate type from module name
            $gate_type = infer_gate_type($module_name);
        }

        # Extract ports
        if ($in_module) {
            if ($line =~ /\binput\s+(?:wire\s+)?(?:\[.*?\]\s+)?(\w+)/) {
                my $pin = $1;
                push @inputs, $pin unless $exclude_pins{$pin};
            }
            elsif ($line =~ /\boutput\s+(?:wire\s+)?(?:reg\s+)?(?:\[.*?\]\s+)?(\w+)/) {
                my $pin = $1;
                push @outputs, $pin unless $exclude_pins{$pin};
            }
            elsif ($line =~ /endmodule/) {
                last;
            }
        }
    }

    close($fh);

    return ($module_name, \@inputs, \@outputs, $gate_type);
}

sub infer_gate_type {
    my ($name) = @_;

    # SkyWater naming: sky130_fd_sc_hd__GATETYPE_STRENGTH
    # Extract gate type portion
    my $gate = $name;

    # Remove common prefixes
    $gate =~ s/^sky130_\w+_\w+_\w+__//;  # SkyWater prefix
    $gate =~ s/_\d+$//;                   # Remove drive strength suffix

    # Common gate types
    return 'AND'    if $gate =~ /^and/i;
    return 'NAND'   if $gate =~ /^nand/i;
    return 'OR'     if $gate =~ /^(or|nor)/i && $gate !~ /^nor/i;
    return 'NOR'    if $gate =~ /^nor/i;
    return 'XOR'    if $gate =~ /^xor/i;
    return 'XNOR'   if $gate =~ /^xnor/i;
    return 'INV'    if $gate =~ /^inv/i;
    return 'BUF'    if $gate =~ /^buf/i;
    return 'MUX'    if $gate =~ /^(mux|mx)/i;
    return 'DFF'    if $gate =~ /^(dff|df)/i;
    return 'LATCH'  if $gate =~ /^(latch|dlatch)/i;
    return 'AOI'    if $gate =~ /^(aoi|a\d+o\d+i)/i;
    return 'OAI'    if $gate =~ /^(oai|o\d+a\d+i)/i;

    return 'UNKNOWN';
}

sub generate_mdt_model {
    my ($fh, $name, $inputs_ref, $outputs_ref, $type) = @_;
    my @inputs = @$inputs_ref;
    my @outputs = @$outputs_ref;

    return unless @outputs;  # Need at least one output

    my $output = $outputs[0];  # Primary output

    # Build port list - MDT format is (outputs, inputs)
    my @all_ports = (@outputs, @inputs);
    my $port_list = join(", ", @all_ports);

    print $fh "model $name ($port_list) (\n";

    # Declare inputs - format: input (A, B, ...) ()
    if (@inputs) {
        print $fh "  input (" . join(", ", @inputs) . ") ()\n";
    }

    # Generate logic based on gate type
    # Use primitives in format: primitive = _operation InstanceName (inputs..., output);

    if ($type eq 'INV' && @inputs >= 1) {
        # Inverter: primitive = _inv I0 (A, Y);
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _inv I0 (" . $inputs[0] . ", $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'BUF' && @inputs >= 1) {
        # Buffer: primitive = _buf I0 (A, Y);
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _buf I0 (" . $inputs[0] . ", $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'AND') {
        # AND gate: primitive = _and I0 (A, B, ..., Y);
        my $input_list = join(", ", @inputs);
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _and I0 ($input_list, $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'NAND') {
        # NAND gate: primitive = _nand I0 (A, B, ..., Y);
        my $input_list = join(", ", @inputs);
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _nand I0 ($input_list, $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'OR') {
        # OR gate: primitive = _or I0 (A, B, ..., Y);
        my $input_list = join(", ", @inputs);
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _or I0 ($input_list, $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'NOR') {
        # NOR gate: primitive = _nor I0 (A, B, ..., Y);
        my $input_list = join(", ", @inputs);
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _nor I0 ($input_list, $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'XOR') {
        # XOR gate: primitive = _xor I0 (A, B, ..., Y);
        my $input_list = join(", ", @inputs);
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _xor I0 ($input_list, $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'XNOR') {
        # XNOR gate: primitive = _xnor I0 (A, B, ..., Y);
        my $input_list = join(", ", @inputs);
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _xnor I0 ($input_list, $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'AOI' && @inputs >= 3) {
        # AOI21: AND-OR-Invert with internal node
        # Assume first 2 inputs are ANDed, then OR with remaining, then invert
        my @and_inputs = ($inputs[0], $inputs[1]);
        my @or_inputs = @inputs[2..$#inputs];

        print $fh "  output ($output) ()\n";
        print $fh "  intern(n1) (\n";
        print $fh "    primitive = _and I0 (" . join(", ", @and_inputs) . ", n1);\n";
        print $fh "    primitive = _nor I1 (" . join(", ", @or_inputs, "n1") . ", $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'OAI' && @inputs >= 3) {
        # OAI21: OR-AND-Invert with internal node
        # Assume first 2 inputs are ORed, then AND with remaining, then invert
        my @or_inputs = ($inputs[0], $inputs[1]);
        my @and_inputs = @inputs[2..$#inputs];

        print $fh "  output ($output) ()\n";
        print $fh "  intern(n1) (\n";
        print $fh "    primitive = _or I0 (" . join(", ", @or_inputs) . ", n1);\n";
        print $fh "    primitive = _nand I1 (" . join(", ", @and_inputs, "n1") . ", $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'MUX' && @inputs >= 3) {
        # MUX: primitive = _mux I0 (sel, in0, in1, ..., Y);
        # Assume last input is select
        my @data_inputs = @inputs[0..$#inputs-1];
        my $sel = $inputs[-1];
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _mux I0 ($sel, " . join(", ", @data_inputs) . ", $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'DFF' && @inputs >= 2) {
        # D flip-flop: primitive = _dff I0 (D, CLK, Q);
        my $d = $inputs[0];
        my $clk = $inputs[1];
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _dff I0 ($d, $clk, $output);\n";
        print $fh "  )\n";
    }
    elsif ($type eq 'LATCH' && @inputs >= 2) {
        # D latch: primitive = _dlat I0 (D, G, Q);
        my $d = $inputs[0];
        my $g = $inputs[1];
        print $fh "  output ($output) (\n";
        print $fh "    primitive = _dlat I0 ($d, $g, $output);\n";
        print $fh "  )\n";
    }
    else {
        # Unknown gate type - default to buffer
        print $fh "  output ($output) (\n";
        if (@inputs) {
            print $fh "    primitive = _buf I0 (" . $inputs[0] . ", $output);\n";
        }
        print $fh "  )\n";
    }

    print $fh ")\n";
}

sub print_usage {
    print <<'USAGE';
Usage: setup_verilog_atpg.pl [OPTIONS] TARGET_DIR

Setup ATPG testing environment for Verilog library cells

Arguments:
  TARGET_DIR            Target directory to search for Verilog files
                        (e.g., skywater-pdk-libs-sky130_fd_sc_hdll)

Options:
  --dry-run             Show what would be done without making changes
  --exclude DIR [...]   Directory names to exclude from search
                        (default: xatpg .git __pycache__)
  --verbose, -v         Verbose output
  --help, -h            Show this help message

Examples:
  # Setup ATPG for skywater PDK
  setup_verilog_atpg.pl /path/to/skywater-pdk-libs-sky130_fd_sc_hdll

  # Dry run to see what would be done
  setup_verilog_atpg.pl --dry-run /path/to/skywater-pdk-libs-sky130_fd_sc_hdll

  # Process specific directory
  setup_verilog_atpg.pl ./verilog_lib
USAGE
}
