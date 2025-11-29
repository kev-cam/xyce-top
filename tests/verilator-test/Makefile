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
TEST_NAME = simple_inv
VERILOG_SRC = $(TEST_NAME).v
MODULE_NAME = $(TEST_NAME)
VERILATOR_CLASS = V$(TEST_NAME)
TARGET = $(TEST_NAME)_xyce.so
STANDALONE_TEST = $(TEST_NAME)_vexe
BRIDGE_SRC = $(TEST_NAME)_xyce.C
BRIDGE_HDR = $(TEST_NAME)_xyce.h
WRAPPER_CIR = $(TEST_NAME).cir
VERILATOR_SRCS = $(VERILATOR_INC)/verilated.cpp $(VERILATOR_INC)/verilated_threads.cpp
VERILATOR_LIB = obj_dir/$(VERILATOR_CLASS)__ALL.a
NETLIST = test_$(TEST_NAME).cir
OUTPUT = test.cir.prn
VERILOG2XYCE = ../scripts/verilog2xyce.pl

.PHONY: all build verilate test clean plot help generate standalone

all: build standalone test-cir

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

%.out: standalone

test-cir: $(TEST_NAME).out
	../scripts/standalone2xyce.pl $(TEST_NAME).out -o test__$(TEST_NAME).cir

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
	@echo "Building $(TEST_NAME) test..."
	../scripts/generate_test.pl -m $(TEST_NAME) -v $(TEST_NAME).v
	$(CXX) $(CXXFLAGS) -o $(STANDALONE_TEST) test_$(TEST_NAME).cpp \
		$(VERILATOR_SRCS) $(VERILATOR_LIB)

standalone: $(STANDALONE_TEST)
	@echo "Running standalone Verilator test..."
	./$(STANDALONE_TEST) | tee $(TEST_NAME).out

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
	rm -f test_* *.out *.cir* *.log *.h *.C *.so
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
	@echo "  make test-cir   - Xyce version of test"
	@echo "  make plot       - Generate waveform plot"
	@echo "  make clean      - Remove all generated files"
	@echo "  make all        - Full build (default)"
