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

# Parse command line options
GetOptions(
    'dry-run'     => \$dry_run,
    'verbose|v'   => \$verbose,
    'exclude=s@'  => \@exclude_dirs,
    'help|h'      => \$help,
) or die "Error in command line arguments\n";

if ($help || @ARGV == 0) {
    print_usage();
    exit($help ? 0 : 1);
}

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
my @verilog_dirs = find_verilog_directories($target_dir, \@exclude_dirs);

unless (@verilog_dirs) {
    print "\nNo Verilog files found in $target_dir\n";
    exit 0;
}

my $dir_count = scalar @verilog_dirs;
print "\nFound $dir_count ", ($dir_count == 1 ? "directory" : "directories"),
      " containing Verilog files\n";

# Setup ATPG for each directory
my $success_count = 0;
foreach my $verilog_dir (@verilog_dirs) {
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
    my ($root_path, $exclude_ref) = @_;
    my %exclude_hash = map { $_ => 1 } @$exclude_ref;
    my %verilog_dirs;

    my $wanted = sub {
        my $file = $_;
        my $dir = $File::Find::dir;

        # Skip excluded directories
        if (-d $file) {
            foreach my $excluded (@$exclude_ref) {
                if ($file eq $excluded || $dir =~ /\Q$excluded\E/) {
                    $File::Find::prune = 1;
                    return;
                }
            }
        }

        # Look for .v files
        if (-f $file && $file =~ /\.v$/) {
            $verilog_dirs{$dir} = 1;
        }
    };

    find($wanted, $root_path);

    return sort keys %verilog_dirs;
}

sub find_verilog_files {
    my ($directory) = @_;
    my @files;

    return () unless -d $directory;

    opendir(my $dh, $directory) or do {
        warn "Cannot open directory $directory: $!\n";
        return ();
    };

    while (my $file = readdir($dh)) {
        next if $file =~ /^\./;  # Skip hidden files
        next unless $file =~ /\.v$/;  # Only .v files
        my $full_path = File::Spec->catfile($directory, $file);
        push @files, $file if -f $full_path;
    }

    closedir($dh);

    return sort @files;
}

sub setup_atpg_directory {
    my ($verilog_dir, $dry_run) = @_;

    my @verilog_files = find_verilog_files($verilog_dir);

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

    print $fh "# Makefile for FAN_ATPG testing\n";
    print $fh "# Auto-generated for directory: $parent_dir\n";
    print $fh "# Generated by setup_verilog_atpg.pl\n";
    print $fh "\n";
    print $fh "# Configuration\n";
    print $fh "VERILOG_DIR = ..\n";
    print $fh "FAN_ATPG = fan_atpg\n";
    print $fh "VERILOG_FILES = ", join(" ", @verilog_files), "\n";
    print $fh "\n";
    print $fh "# Test targets (one per Verilog file)\n";
    print $fh "TEST_TARGETS = ", join(" ", map { "$_.test" } @stems), "\n";
    print $fh "REPORT_FILES = ", join(" ", map { "$_.rpt" } @stems), "\n";
    print $fh "\n";
    print $fh "# Default target\n";
    print $fh ".PHONY: all clean help test\n";
    print $fh "\n";
    print $fh "all: test\n";
    print $fh "\n";
    print $fh "# Run all ATPG tests\n";
    print $fh "test: \$(TEST_TARGETS)\n";
    print $fh "\t\@echo \"All ATPG tests completed\"\n";
    print $fh "\n";
    print $fh "# Pattern rule for running FAN_ATPG on each Verilog file\n";
    print $fh "%.test: \$(VERILOG_DIR)/%.v\n";
    print $fh "\t\@echo \"Running FAN_ATPG on \$<\"\n";
    print $fh "\t\$(FAN_ATPG) -i \$< -o \$*.rpt || true\n";
    print $fh "\t\@touch \$@\n";
    print $fh "\n";
    print $fh "# Individual test targets\n";

    for (my $i = 0; $i < @stems; $i++) {
        my $stem = $stems[$i];
        my $file = $verilog_files[$i];
        print $fh "\n";
        print $fh "$stem.test: \$(VERILOG_DIR)/$file\n";
        print $fh "\t\@echo \"Testing $file...\"\n";
        print $fh "\t\@\$(FAN_ATPG) -i \$(VERILOG_DIR)/$file -o $stem.rpt 2>&1 | tee $stem.log || true\n";
        print $fh "\t\@touch \$@\n";
    }

    print $fh "\n";
    print $fh "# Clean generated files\n";
    print $fh "clean:\n";
    print $fh "\trm -f \$(TEST_TARGETS) \$(REPORT_FILES) *.log *.atpg *.patterns\n";
    print $fh "\n";
    print $fh "# Show help\n";
    print $fh "help:\n";
    print $fh "\t\@echo \"FAN_ATPG Makefile for Verilog library cells\"\n";
    print $fh "\t\@echo \"\"\n";
    print $fh "\t\@echo \"Targets:\"\n";
    print $fh "\t\@echo \"  all     - Run all ATPG tests (default)\"\n";
    print $fh "\t\@echo \"  test    - Run all ATPG tests\"\n";
    print $fh "\t\@echo \"  clean   - Remove generated test files\"\n";
    print $fh "\t\@echo \"  help    - Show this help message\"\n";
    print $fh "\t\@echo \"\"\n";
    print $fh "\t\@echo \"Individual tests:\"\n";

    foreach my $stem (@stems) {
        print $fh "\t\@echo \"  $stem.test\"\n";
    }

    print $fh "\n";
    print $fh "\t\@echo \"\"\n";
    print $fh "\t\@echo \"Verilog files:\"\n";

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
                push @inputs, $1;
            }
            elsif ($line =~ /\boutput\s+(?:wire\s+)?(?:reg\s+)?(?:\[.*?\]\s+)?(\w+)/) {
                push @outputs, $1;
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

    # Build port list
    my @all_ports = (@inputs, @outputs);
    my $port_list = join(", ", @all_ports);

    print $fh "model $name ($port_list) (\n";

    # Declare inputs
    if (@inputs) {
        print $fh "  input " . join(" ", @inputs) . "\n";
    }

    # Declare outputs
    if (@outputs) {
        print $fh "  output " . join(" ", @outputs) . "\n";
    }

    # Generate logic based on gate type
    my $output = $outputs[0] || 'Y';  # Default output name

    if ($type eq 'INV' && @inputs >= 1) {
        print $fh "  $output = _inv(" . $inputs[0] . ")\n";
    }
    elsif ($type eq 'BUF' && @inputs >= 1) {
        print $fh "  $output = " . $inputs[0] . "\n";
    }
    elsif ($type eq 'AND') {
        my $expr = join(", ", @inputs);
        print $fh "  $output = _and($expr)\n";
    }
    elsif ($type eq 'NAND') {
        my $expr = join(", ", @inputs);
        print $fh "  intern n1\n";
        print $fh "  n1 = _and($expr)\n";
        print $fh "  $output = _inv(n1)\n";
    }
    elsif ($type eq 'OR') {
        my $expr = join(", ", @inputs);
        print $fh "  $output = _or($expr)\n";
    }
    elsif ($type eq 'NOR') {
        my $expr = join(", ", @inputs);
        print $fh "  intern n1\n";
        print $fh "  n1 = _or($expr)\n";
        print $fh "  $output = _inv(n1)\n";
    }
    elsif ($type eq 'XOR') {
        my $expr = join(", ", @inputs);
        print $fh "  $output = _xor($expr)\n";
    }
    elsif ($type eq 'XNOR') {
        my $expr = join(", ", @inputs);
        print $fh "  intern n1\n";
        print $fh "  n1 = _xor($expr)\n";
        print $fh "  $output = _inv(n1)\n";
    }
    elsif ($type eq 'MUX' && @inputs >= 3) {
        # Assume last input is select
        my $sel = pop @inputs;
        print $fh "  $output = _mux($sel, " . join(", ", @inputs) . ")\n";
    }
    elsif ($type eq 'DFF' && @inputs >= 1) {
        # Simple D flip-flop
        my $d = $inputs[0];
        my $clk = $inputs[1] || 'CLK';
        print $fh "  $output = _dff($d, $clk)\n";
    }
    else {
        # Default: treat as buffer for unknown types
        print $fh "  // Unknown gate type: $type\n";
        if (@inputs && @outputs) {
            print $fh "  $output = " . $inputs[0] . "\n";
        }
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
