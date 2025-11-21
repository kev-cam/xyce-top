# Xyce External Code Loading - Test Suite Makefile

# Test directories
GATES_TEST = gates-test
VERILATOR_TEST = verilator-test

.PHONY: all build test clean help gates verilator plot

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
	@echo "  make all        - Build all tests (default)"
	@echo "  make build      - Build all tests"
	@echo "  make test       - Run all tests"
	@echo "  make gates      - Build and run gates test"
	@echo "  make verilator  - Build and run verilator test"
	@echo "  make plot       - Generate waveform plots for all tests"
	@echo "  make clean      - Remove all generated files"
	@echo "  make help       - Show this help message"
	@echo ""
	@echo "Individual Tests:"
	@echo "  cd gates-test && make help       - Gates test options"
	@echo "  cd verilator-test && make help   - Verilator test options"
	@echo ""
	@echo "Tools:"
	@echo "  tools/plot_xyce.sh <file.prn>           - Plot Xyce output"
	@echo "  verilator-test/verilog2xyce.pl --help   - Verilog wrapper generator"
	@echo ""
	@echo "Documentation:"
	@echo "  See README.md for detailed information"
