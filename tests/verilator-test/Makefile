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
STANDALONE_TEST = test_standalone
BRIDGE_SRC = simple_inv_xyce.C
BRIDGE_HDR = simple_inv_xyce.h
WRAPPER_CIR = simple_inv.cir
VERILATOR_SRCS = $(VERILATOR_INC)/verilated.cpp $(VERILATOR_INC)/verilated_threads.cpp
VERILATOR_LIB = obj_dir/$(VERILATOR_CLASS)__ALL.a
NETLIST = test_simple_inv.cir
OUTPUT = test.cir.prn
VERILOG2XYCE = ../scripts/verilog2xyce.pl

.PHONY: all build verilate test clean plot help generate standalone

all: build standalone test.cir

# Generate wrapper files using verilog2xyce.pl
generate: $(BRIDGE_SRC)

$(BRIDGE_SRC) $(BRIDGE_HDR) $(WRAPPER_CIR): $(VERILOG_SRC) $(VERILOG2XYCE)
	@echo "Generating Xyce wrapper files..."
	$(VERILOG2XYCE) -m $(MODULE_NAME)

# Full build process
build: generate verilate wrap $(TARGET)

# create wrapper
wrap:
	../scripts/verilog2xyce.pl -m=$(MODULE_NAME)

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

test.cir: standalone
	../scripts/standalone2xyce.pl test.out -o test.cir

# Run test
test: build
	@echo "Running Xyce simulation..."
	-$(XYCE_BIN) $(NETLIST) > $(MODULE_NAME).log 2>&1
	@if [ -f $(OUTPUT) ]; then \
		echo "Test completed successfully!"; \
		echo "Output: $(OUTPUT) ($$(wc -l < $(OUTPUT)) lines)"; \
	else \
                tail $(MODULE_NAME).log ;\
		echo "Test failed - no output generated"; \
		exit 1; \
	fi

# Build and run standalone Verilator test (no Xyce)
$(STANDALONE_TEST): verilate
	@echo "Building standalone test..."
	@echo '#include <iostream>' > test_standalone.cpp
	@echo '#include <iomanip>' >> test_standalone.cpp
	@echo '#include "$(VERILATOR_CLASS).h"' >> test_standalone.cpp
	@echo '#include "verilated.h"' >> test_standalone.cpp
	@echo 'int main(int argc, char** argv) {' >> test_standalone.cpp
	@echo '    Verilated::commandArgs(argc, argv);' >> test_standalone.cpp
	@echo '    $(VERILATOR_CLASS)* top = new $(VERILATOR_CLASS);' >> test_standalone.cpp
	@echo '    double time_ns = 0.0;' >> test_standalone.cpp
	@echo '    double time_step = 1.0;  // 1ns per step' >> test_standalone.cpp
	@echo '    std::cout << "# Testing $(MODULE_NAME)" << std::endl;' >> test_standalone.cpp
	@echo '    std::cout << "# time(ns) in out" << std::endl;' >> test_standalone.cpp
	@echo '    for (int i = 0; i < 10; i++) {' >> test_standalone.cpp
	@echo '        top->in = (i % 2);' >> test_standalone.cpp
	@echo '        top->eval();' >> test_standalone.cpp
	@echo '        std::cout << std::fixed << std::setprecision(2) << time_ns << " " << (int)top->in << " " << (int)top->out << std::endl;' >> test_standalone.cpp
	@echo '        time_ns += time_step;' >> test_standalone.cpp
	@echo '    }' >> test_standalone.cpp
	@echo '    delete top;' >> test_standalone.cpp
	@echo '    return 0;' >> test_standalone.cpp
	@echo '}' >> test_standalone.cpp
	$(CXX) $(CXXFLAGS) -o $(STANDALONE_TEST) test_standalone.cpp \
		$(VERILATOR_SRCS) $(VERILATOR_LIB)

standalone: $(STANDALONE_TEST)
	@echo "Running standalone Verilator test..."
	./$(STANDALONE_TEST) | tee test.out

# Generate plot
plot: $(OUTPUT)
	@if [ -f ../scripts/plot_xyce.pl ]; then \
		 ../scripts/plot_xyce.pl $(OUTPUT) $(patsubst %.prn,%.png,$(OUTPUT)); \
	else \
		echo "Plotting script not found"; \
	fi

# Clean generated files
clean:
	rm -f $(TARGET) $(OUTPUT) *.png
	rm -f $(BRIDGE_SRC) $(BRIDGE_HDR) $(WRAPPER_CIR)
	rm -f $(STANDALONE_TEST) test_standalone.cpp test.out test.cir
	rm -rf obj_dir

help:
	@echo "Verilator Test Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make build      - Generate wrappers, run Verilator and build shared library"
	@echo "  make generate   - Generate Xyce wrapper files using verilog2xyce.pl"
	@echo "  make verilate   - Run Verilator only (generate C++)"
	@echo "  make test       - Run Xyce simulation with external device"
	@echo "  make standalone - Build and run standalone Verilator test (no Xyce)"
	@echo "  make test.cir   - Xyce version of test"
	@echo "  make plot       - Generate waveform plot"
	@echo "  make clean      - Remove all generated files"
	@echo "  make all        - Full build (default)"
