# Xyce External Code Loading Examples

This directory contains examples and tools for using Xyce's external code loading feature to integrate custom C/C++ models and Verilator-based digital logic.

## Directory Structure

```
tests/
├── Makefile           - Top-level makefile for all tests
├── README.md          - This file
├── xbridge.C          - Shared bridge implementation
├── xbridge.h          - Shared bridge header
├── gates.h            - Shared gate class definitions
├── gates-test/        - Original C++ inverter example
│   ├── Makefile
│   ├── gates.C        - Inverter implementation
│   ├── inv.cir        - Test netlist
│   └── inv-string.cir - Alternative test
├── verilator-test/    - Verilator integration example
│   ├── Makefile
│   ├── verilog2xyce.pl       - Automated wrapper generator
│   ├── simple_inv.v          - Verilog inverter
│   ├── verilator_xyce_bridge.cpp - Bridge code
│   └── inv_verilator.cir     - Test netlist
└── tools/             - Shared utilities
    ├── plot_xyce.sh   - Plotting script
    └── plot.gp        - Gnuplot example
```

## Quick Start

### Build and Run All Tests

```bash
make test              # Build and run all tests
make build             # Build all (no run)
make clean             # Clean all generated files
make help              # Show all options
```

### Run Individual Tests

```bash
# Gates test (C++)
make gates             # Build and run
cd gates-test && make test

# Verilator test
make verilator         # Build and run
cd verilator-test && make test
```

## Test Details

### 1. Gates Test (C++ Implementation)

**Location:** `gates-test/`

A hand-coded inverter gate model demonstrating the core external code interface.

**Build:**
```bash
cd gates-test
make build             # Build gates.so
make test              # Run simulation
make plot              # Generate waveform
```

**Files:**
- `gates.C` - Inverter model with timing and voltage parameters
- `inv.cir` - SPICE netlist using gates.so
- Output: `inv.cir.prn` (384 timesteps, 0-40ns)

### 2. Verilator Test (Verilog Integration)

**Location:** `verilator-test/`

Demonstrates analog-digital co-simulation using Verilator to compile Verilog to C++.

**Build:**
```bash
cd verilator-test
make build             # Run Verilator + build library
make verilate          # Run Verilator only
make test              # Run simulation
make plot              # Generate waveform
```

**Files:**
- `simple_inv.v` - Verilog inverter (combinational logic)
- `verilator_xyce_bridge.cpp` - C++ wrapper connecting Verilator to Xyce
- `inv_verilator.cir` - SPICE netlist
- Output: `inv_verilator.cir.prn` (132 timesteps, 0-32ns)

**Automated Wrapper Generation:**
```bash
./verilog2xyce.pl --help                    # Show help
./verilog2xyce.pl my_module.v               # Generate wrapper
./verilog2xyce.pl -n my_module.v            # Generate wrapper + netlist
./verilog2xyce.pl -b -n my_module.v         # Full build
```

## Plotting Results

### Automatic Plotting

```bash
# From tests/ directory
tools/plot_xyce.sh gates-test/inv.cir.prn
tools/plot_xyce.sh verilator-test/inv_verilator.cir.prn

# Or use make targets
make plot              # Plot all tests
cd gates-test && make plot
cd verilator-test && make plot
```

### Manual Gnuplot

Create a `.gp` file:
```gnuplot
set terminal png size 1200,800
set output 'custom.png'
set xlabel 'Time (s)'
set ylabel 'Voltage (V)'
set grid

plot 'inv.cir.prn' using 2:3 with lines title 'V(VDD)', \
     '' using 2:4 with lines title 'V(A)', \
     '' using 2:5 with lines title 'V(B)'
```

Run: `gnuplot custom.gp`

## .prn File Format

Xyce outputs space-separated data with headers:

```
Index       TIME             V(VDD)             V(A)              V(B)
0        0.00000000e+00    3.10000000e+00    0.00000000e+00    0.00000000e+00
1        5.00000000e-12    3.09950000e+00    0.00000000e+00    0.00000000e+00
...
```

- Column 1: Index
- Column 2: TIME (use for x-axis)
- Columns 3+: Your signals

## External Code URI Format

In SPICE netlists:

```spice
VPWL OUT 0 PWL FILE "code:./library.so:AttachFunction:args"
```

Components:
- `./library.so` - Path to shared library
- `AttachFunction` - Entry point function name
- `args` - Comma-separated arguments (e.g., `output,Vtol=1e-3,Delay=5e-12`)

## Makefile Targets

### Top Level (`tests/`)

```bash
make all        # Build all tests (default)
make build      # Build all tests
make test       # Build and run all tests
make gates      # Build and run gates test
make verilator  # Build and run verilator test
make plot       # Generate plots for all tests
make clean      # Remove all generated files
make help       # Show help
```

### Per-Test (`gates-test/` or `verilator-test/`)

```bash
make build      # Build shared library
make test       # Run Xyce simulation
make plot       # Generate waveform plot
make clean      # Remove generated files
make help       # Show test-specific help
```

## Creating New Tests

### 1. From Verilog (Recommended)

```bash
cd verilator-test
./verilog2xyce.pl -b -n my_module.v
/usr/local/xyce_patched/bin/Xyce my_module_test.cir
```

The script automatically:
- Parses your Verilog module
- Generates C++ bridge code
- Creates test SPICE netlist
- Builds shared library

### 2. Manual C++ Implementation

1. Copy `gates-test/` as a template
2. Modify `gates.C` with your model
3. Update `inv.cir` netlist
4. `make test`

## Architecture

### Bridge Interface

External libraries must provide:
- **Attachment function:** `BridgeFn AttachXXX(PWLinDynData*, void**, const char*)`
- **Bridge functions:** For each signal (input, output, vdd)
- **Cross handlers:** Callbacks for signal transitions

### Signal Flow

1. Xyce loads `.so` via `dlopen()`
2. Calls attachment function for each PWL source
3. Bridge creates handler instances
4. Xyce calls bridge functions during simulation
5. Cross handlers update internal state
6. Bridge updates Xyce's time-voltage vectors

### Key Classes

- `Gate` - Base class for gate models (in `gates.h`)
- `GateX<N>` - Template for N-input gates
- `PwlHandler` - Interface to Xyce PWL sources
- `GatePwlHandler` - Gate-specific handler

## Tips

- Use `-O0 -g` in CXXFLAGS for debugging
- Check Xyce output file existence (`.prn`) to verify success
- Xyce may exit with non-zero status even on success
- Verilator requires `-fPIC` flag for shared libraries
- Test netlists assume 3V logic levels (configurable)

## References

- **Xyce User Guide:** https://xyce.sandia.gov/documentation/
- **Verilator Manual:** https://verilator.org/guide/latest/
- **Gnuplot Documentation:** http://gnuplot.info/docs_5.4/
- **External Code Loading Patch:** See `xbridge.{h,C}` for API

## Troubleshooting

**Problem:** `undefined symbol` when loading `.so`

**Solution:** Check that all required functions are exported and linked

**Problem:** Verilator build fails with relocation errors

**Solution:** Ensure `-fPIC` flag is used in Verilator compilation

**Problem:** Xyce can't find library

**Solution:** Use absolute path or `./` prefix for libraries in same directory

**Problem:** Simulation produces no output

**Solution:** Check `.prn` file was created; verify library loaded successfully
