# Verilog ATPG Setup Tests

This directory contains tools for setting up ATPG (Automatic Test Pattern Generation) testing environments for Verilog library cells.

## Scripts

### setup_verilog_atpg.py

A Python script that traverses a directory hierarchy (such as the skywater-pdk-libs-sky130_fd_sc_hdll repository), finds directories containing Verilog library cell files (.v), and automatically:

1. Creates an `xatpg` subdirectory in each directory containing Verilog files
2. Generates a Makefile in each `xatpg` directory to run FAN_ATPG tests
3. Creates a README in each `xatpg` directory with usage instructions

## Usage

### Basic Usage

```bash
# Run on the skywater PDK library (replace with actual path)
./setup_verilog_atpg.py /path/to/skywater-pdk-libs-sky130_fd_sc_hdll

```

### Dry Run (Preview Mode)

To see what would be done without making any changes:

```bash
./setup_verilog_atpg.pl --dry-run /path/to/skywater-pdk-libs-sky130_fd_sc_hdll
`

### Options

- `--dry-run` - Show what would be done without making changes
- `--exclude DIR [DIR ...]` - Exclude specific directory names from search (default: xatpg .git __pycache__)
- `--verbose`, `-v` - Verbose output
- `--help`, `-h` - Show help message

### Examples

```bash
# Preview what would be done
./setup_verilog_atpg.py --dry-run ~/repos/skywater-pdk-libs-sky130_fd_sc_hdll

# Actually create the ATPG structure
./setup_verilog_atpg.py ~/repos/skywater-pdk-libs-sky130_fd_sc_hdll

# Exclude additional directories
./setup_verilog_atpg.py --exclude xatpg .git build /path/to/verilog/lib

./setup_verilog_atpg.pl --dry-run ~/repos/skywater-pdk-libs-sky130_fd_sc_hdll

# Actually create the ATPG structure
./setup_verilog_atpg.pl ~/repos/skywater-pdk-libs-sky130_fd_sc_hdll

# Exclude additional directories
./setup_verilog_atpg.pl --exclude xatpg .git build /path/to/verilog/lib

# Show help
./setup_verilog_atpg.pl --help
``

## What Gets Created

For each directory containing Verilog files, the script creates:

### xatpg/Makefile

A Makefile with the following targets:

- `make test` or `make all` - Run all ATPG tests
- `make <cellname>.test` - Run ATPG test for a specific cell
- `make clean` - Remove generated test files
- `make help` - Show available targets

### xatpg/README.md

Documentation for the specific xatpg directory, including:
- Location of the parent Verilog files
- Number of library cells found
- Usage instructions

## Running ATPG Tests

After running the setup script, you can run ATPG tests:

```bash
# Navigate to any generated xatpg directory
cd /path/to/verilog/library/xatpg

# Run all tests
make test

# Run a specific test
make and2_1.test

# Clean up generated files
make clean

# Show all available targets
make help
```

## Requirements

- Perl 5.10 or later with standard modules:
  - File::Find
  - File::Path
  - File::Spec
  - File::Basename
  - Getopt::Long
  - Cwd

- FAN_ATPG tool (must be in your PATH or modify the Makefile to specify full path)

## Notes

- The script automatically excludes `.git`, `__pycache__`, and existing `xatpg` directories
- Existing xatpg directories will be updated/overwritten
- The script creates Makefiles that look for the `fan_atpg` command - adjust if your ATPG tool has a different name
- Each generated Makefile references Verilog files in the parent directory using relative paths (`../*.v`)
