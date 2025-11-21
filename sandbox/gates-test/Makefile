# Makefile for gates-test (original C++ inverter example)

# Paths
XYCE_BIN = /usr/local/xyce_patched/bin/Xyce
XYCE_INC = /usr/local/xyce_patched/include
TRILINOS_INC = /home/user/trilinos-14.4-install/include
PARENT_DIR = ..

# Compiler settings
CXX = g++
CXXFLAGS = -fPIC -std=c++11 -I$(PARENT_DIR) -I$(XYCE_INC) -I$(TRILINOS_INC)
LDFLAGS = -shared

# Targets
TARGET = gates.so
SOURCES = gates.C $(PARENT_DIR)/xbridge.C
NETLIST = inv.cir
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
	@if [ -f ../tools/plot_xyce.sh ]; then \
		../tools/plot_xyce.sh $(OUTPUT); \
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
