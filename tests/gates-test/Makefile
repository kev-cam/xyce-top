# Makefile for gates-test (original C++ inverter example)

ifeq ($(XYCE_INSTALL_DIR),)
  XYCE_INSTALL_DIR=/usr/local
endif

# Paths
XYCE_BIN = $(XYCE_INSTALL_DIR)/bin/Xyce
XYCE_INC = $(XYCE_INSTALL_DIR)/include
XYCE_SRC = ../../src/DeviceModelPKG/Core
TRILINOS_INC = $(TRILINOS_INSTALL_DIR)/include
PARENT_DIR = ..
CXX_OPT_FLAGS=-g -O0

# Compiler settings
CXX = g++
CXXFLAGS = $(CXX_OPT_FLAGS) -fPIC -std=c++11 -I$(PARENT_DIR) -I$(XYCE_SRC) -I$(XYCE_INC) -I$(TRILINOS_INC)
LDFLAGS = -shared

# Targets
TARGET = gates.so
SOURCES = gates.C $(PARENT_DIR)/xbridge.C
NETLIST = inv-string.cir
OUTPUT = inv.cir.prn

.PHONY: all build test clean plot

all: build

# Build shared library
build: $(TARGET)

$(TARGET): $(SOURCES)
	$(CXX) $(LDFLAGS) $(CXXFLAGS) -o $@ $^

# Run test
test: $(TARGET)
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
	@if [ -f ../scripts/plot_xyce.sh ]; then \
		 ../scripts/plot_xyce.sh $(OUTPUT); \
	else \
		echo "Plotting script not found"; \
	fi

# Clean generated files
clean:
	rm -f $(TARGET) $(OUTPUT) *.png

help:
	@echo "Gates Test Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make build   - Build gates.so shared library"
	@echo "  make test    - Run Xyce simulation"
	@echo "  make plot    - Generate waveform plot"
	@echo "  make clean   - Remove generated files"
	@echo "  make all     - Build only (default)"
