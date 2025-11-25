# Xyce External Code Loading - Test Suite Makefile

# Test directories
GATES_TEST = gates-test
VERILATOR_TEST = verilator-test

# Cell library path for ATPG setup (can be overridden)
CELL_LIB_PATH ?= $(CELL_LIB_ROOT)

# ATPG setup script
ATPG_SETUP = scripts/setup_verilog_atpg.pl

# Xyce
export XYCE_INSTALL_DIR=/usr/local

# Trilinos
export TRILINOS_INSTALL_DIR=/usr/local

.PHONY: all build test clean help gates verilator plot cell-library cell-library-dry-run

# Default target - build all tests
all: build

# Build all tests
build:
	@echo "=== Building all tests ==="
	@$(MAKE) -C $(GATES_TEST) build
	@$(MAKE) -C $(VERILATOR_TEST) build
	@echo "=== Build complete ==="

# Run all tests
test:
	@echo "=== Running all tests ==="
	@echo ""
	@echo "--- Gates Test (C++) ---"
	@$(MAKE) -C $(GATES_TEST) test
	@echo ""
	@echo "--- Verilator Test ---"
	@$(MAKE) -C $(VERILATOR_TEST) test
	@echo ""
	@echo "=== All tests complete ==="

# Build and test gates example
gates:
	@echo "=== Gates Test ==="
	@$(MAKE) -C $(GATES_TEST) build test

# Build and test verilator example
verilator:
	@echo "=== Verilator Test ==="
	@$(MAKE) -C $(VERILATOR_TEST) build test

# Generate plots for all tests
plot:
	@echo "=== Generating plots ==="
	@$(MAKE) -C $(GATES_TEST) plot
	@$(MAKE) -C $(VERILATOR_TEST) plot
	@echo "=== Plots complete ==="

# Setup ATPG testing for cell library
cell-library:
	@echo "=== Setting up ATPG for Cell Library ==="
	@if [ ! -d "$(CELL_LIB_PATH)" ]; then \
		echo "Error: Cell library path not found: $(CELL_LIB_PATH)"; \
		echo "Set CELL_LIB_PATH variable to your cell library directory"; \
		echo "Example: make cell-library CELL_LIB_PATH=/path/to/skywater-pdk"; \
		exit 1; \
	fi
	@$(ATPG_SETUP) $(CELL_LIB_PATH)
	@echo "=== ATPG setup complete ==="

# Dry-run of ATPG setup
cell-library-dry-run:
	@echo "=== ATPG Setup Dry Run ==="
	@if [ ! -d "$(CELL_LIB_PATH)" ]; then \
		echo "Error: Cell library path not found: $(CELL_LIB_PATH)"; \
		echo "Set CELL_LIB_PATH variable to your cell library directory"; \
		echo "Example: make cell-library-dry-run CELL_LIB_PATH=/path/to/skywater-pdk"; \
		exit 1; \
	fi
	@$(ATPG_SETUP) --dry-run $(CELL_LIB_PATH)

# Clean all tests
clean:
	@echo "=== Cleaning all tests ==="
	@$(MAKE) -C $(GATES_TEST) clean
	@$(MAKE) -C $(VERILATOR_TEST) clean
	@rm -f tools/*.png
	@echo "=== Clean complete ==="

# Show help
help:
	@echo "Xyce External Code Loading - Test Suite"
	@echo ""
	@echo "This directory contains examples of integrating external C/C++ code"
	@echo "and Verilator-based digital logic with Xyce circuit simulator."
	@echo ""
	@echo "Targets:"
	@echo "  make all                  - Build all tests (default)"
	@echo "  make build                - Build all tests"
	@echo "  make test                 - Run all tests"
	@echo "  make gates                - Build and run gates test"
	@echo "  make verilator            - Build and run verilator test"
	@echo "  make cell-library         - Setup ATPG for cell library"
	@echo "  make cell-library-dry-run - Preview ATPG setup (dry run)"
	@echo "  make plot                 - Generate waveform plots for all tests"
	@echo "  make clean                - Remove all generated files"
	@echo "  make help                 - Show this help message"
	@echo ""
	@echo "Individual Tests:"
	@echo "  cd gates-test && make help       - Gates test options"
	@echo "  cd verilator-test && make help   - Verilator test options"
	@echo ""
	@echo "Tools:"
	@echo "  tools/plot_xyce.sh <file.prn>           - Plot Xyce output"
	@echo "  scripts/verilog2xyce.pl --help          - Verilog wrapper generator"
	@echo "  setup_verilog_atpg.pl --help            - ATPG setup script"
	@echo ""
	@echo "Cell Library ATPG:"
	@echo "  make cell-library CELL_LIB_PATH=/path/to/library"
	@echo ""
	@echo "Documentation:"
	@echo "  See README.md for detailed information"
