# Makefile for verilator-test (Verilator-based digital logic integration)

# Paths
XYCE_BIN = $(XYCE_INSTALL_DIR)/bin/Xyce
XYCE_INC = $(XYCE_INSTALL_DIR)/include
XYCE_SRC = ../../src/DeviceModelPKG/Core
TRILINOS_INC = $(TRILINOS_INSTALL_DIR)/include
VERILATOR_INC = /usr/share/verilator/include
PARENT_DIR = ..

# Compiler settings
CXX = g++
CXXFLAGS = -fPIC -std=c++11 -I$(PARENT_DIR) -I$(XYCE_SRC) -I$(XYCE_INC) -I$(TRILINOS_INC) -I$(VERILATOR_INC) -Iobj_dir -I.
LDFLAGS = -shared

# Verilator settings
VERILATOR = verilator
VERILATOR_FLAGS = --cc -CFLAGS "-fPIC"

# Files
VERILOG_SRC = simple_inv.v
MODULE_NAME = simple_inv
VERILATOR_CLASS = Vsimple_inv
TARGET = simple_inv_xyce.so
BRIDGE_SRC = simple_inv_xyce.C
BRIDGE_HDR = simple_inv_xyce.h
WRAPPER_CIR = simple_inv_xyce.cir
VERILATOR_SRCS = $(VERILATOR_INC)/verilated.cpp $(VERILATOR_INC)/verilated_threads.cpp
VERILATOR_LIB = obj_dir/$(VERILATOR_CLASS)__ALL.a
NETLIST = test_simple_inv.cir
OUTPUT = test_simple_inv.cir.prn
VERILOG2XYCE = ../scripts/verilog2xyce.pl

.PHONY: all build verilate test clean plot help generate

all: build

# Generate wrapper files using verilog2xyce.pl
generate: $(BRIDGE_SRC)

$(BRIDGE_SRC) $(BRIDGE_HDR) $(WRAPPER_CIR): $(VERILOG_SRC) $(VERILOG2XYCE)
	@echo "Generating Xyce wrapper files..."
	$(VERILOG2XYCE) -m $(MODULE_NAME)

# Full build process
build: generate verilate $(TARGET)

# Run Verilator to generate C++
verilate: $(VERILOG_SRC)
	@echo "Running Verilator on $(VERILOG_SRC)..."
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_SRC)
	@echo "Building Verilator library..."
	$(MAKE) -C obj_dir -f $(VERILATOR_CLASS).mk

# Build shared library
$(TARGET): $(BRIDGE_SRC) $(VERILATOR_LIB) $(PARENT_DIR)/xbridge.C
	@echo "Building shared library $(TARGET)..."
	$(CXX) $(LDFLAGS) $(CXXFLAGS) -o $@ \
		$(BRIDGE_SRC) $(PARENT_DIR)/xbridge.C \
		$(VERILATOR_SRCS) $(VERILATOR_LIB)
	@ls -lh $@

# Run test
test: build
	@echo "Running Xyce simulation..."
	-$(XYCE_BIN) $(NETLIST) > /dev/null 2>&1
	@if [ -f $(OUTPUT) ]; then \
		echo "Test completed successfully!"; \
		echo "Output: $(OUTPUT) ($$(wc -l < $(OUTPUT)) lines)"; \
	else \
		echo "Test failed - no output generated"; \
		exit 1; \
	fi

# Generate plot
plot: $(OUTPUT)
	@if [ -f ../tools/plot_xyce.sh ]; then \
		../tools/plot_xyce.sh $(OUTPUT); \
	else \
		echo "Plotting script not found"; \
	fi

# Clean generated files
clean:
	rm -f $(TARGET) $(OUTPUT) *.png
	rm -f $(BRIDGE_SRC) $(BRIDGE_HDR) $(WRAPPER_CIR)
	rm -rf obj_dir

help:
	@echo "Verilator Test Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make build     - Generate wrappers, run Verilator and build shared library"
	@echo "  make generate  - Generate Xyce wrapper files using verilog2xyce.pl"
	@echo "  make verilate  - Run Verilator only (generate C++)"
	@echo "  make test      - Run Xyce simulation"
	@echo "  make plot      - Generate waveform plot"
	@echo "  make clean     - Remove all generated files"
	@echo "  make all       - Full build (default)"
