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

# Parse command line options
GetOptions(
    'dry-run'     => \$dry_run,
    'verbose|v'   => \$verbose,
    'test|t=s'    => \$test,
    'exclude=s@'  => \@exclude_dirs,
    'help|h'      => \$help,
) or die "Error in command line arguments\n";

if ($help || (@ARGV == 0 && ! $test)) {
    print_usage();
    exit($help ? 0 : 1);
}

if ($test) {
    my $script = $test;
    $script =~ s=.*/==;
    open(FANF,">$script-fan");
    print FANF "read_netlist $test\n";
    print FANF "run_atpg\n";
    print FANF "run_logic_sim\n";
    print FANF "exit\n";
    exit 0;
}

my $self = abs_path($0);

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
    print $fh "SETUP_ATPG = $self\n";
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
    print $fh "\t\$(FAN_ATPG) -f \$<-fan </dev/null || true\n";
    print $fh "\t\@touch \$@\n";
    print $fh "\n";
    print $fh "# Individual test targets\n";

    for (my $i = 0; $i < @stems; $i++) {
        my $stem = $stems[$i];
        my $file = $verilog_files[$i];
        print $fh "\n";
        print $fh "$stem.test: \$(VERILOG_DIR)/$file\n";
        print $fh "\t\@echo \"Testing $file...\"\n";
        print $fh "\t\@\$(SETUP_ATPG) -test \$(VERILOG_DIR)/$file\n";
        print $fh "\t\@\$(FAN_ATPG) -f $file-fan 2>&1 </dev/null | tee $stem.log || true\n";
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
