# Xyce External Code Loading Examples

This directory contains examples and tools for using Xyce's external code loading feature to integrate custom C/C++ models and Verilator-based digital logic.

## Contents

### Test Cases

- **gates.so** - Original inverter gate model example (C++)
- **inv.cir** - Test netlist using gates.so
- **verilator-test/** - Verilator integration examples

### Tools

- **plot_xyce.sh** - Quick plotting script for Xyce .prn output files
- **verilator-test/verilog2xyce.pl** - Automated Verilog-to-Xyce wrapper generator

## Quick Start

### Running a Simulation

```bash
# Original C++ test
/usr/local/xyce_patched/bin/Xyce inv.cir

# Verilator-based test
cd verilator-test
/usr/local/xyce_patched/bin/Xyce inv_verilator.cir
```

### Plotting Results

```bash
# Simple: auto-detect all voltage signals
./plot_xyce.sh inv.cir.prn

# Custom output filename
./plot_xyce.sh inv.cir.prn myplot.png
```

The script automatically:
- Reads column headers from .prn file
- Plots all V(...) signals vs TIME
- Generates PNG with nice formatting

### Creating New Verilog Wrappers

```bash
cd verilator-test

# Just generate C++ wrapper
./verilog2xyce.pl my_module.v

# Generate wrapper + test netlist
./verilog2xyce.pl -n my_module.v

# Full build (wrapper + netlist + shared library)
./verilog2xyce.pl -b -n my_module.v

# Custom output prefix
./verilog2xyce.pl -o custom_name -b -n my_module.v
```

## File Formats

### Xyce .prn Output Format

Space-separated columns with header:
```
Index       TIME             V(VDD)             V(A)              V(B)
0        0.00000000e+00    3.10000000e+00    0.00000000e+00    0.00000000e+00
1        5.00000000e-12    3.09950000e+00    0.00000000e+00    0.00000000e+00
...
```

### External Code URI Format

In SPICE netlist:
```spice
VPWL OUT 0 PWL FILE "code:./library.so:AttachFunction:args"
```

Where:
- `./library.so` - Path to shared library
- `AttachFunction` - Entry point function name
- `args` - Comma-separated arguments (e.g., `output,Vtol=1e-3,Delay=5e-12`)

## Examples

### Example 1: Simple Inverter (C++)

See `gates.C` and `inv.cir` for a hand-coded example.

Build:
```bash
g++ -shared -fPIC -o gates.so gates.C xbridge.C \
    -I/usr/local/xyce_patched/include \
    -I/home/user/trilinos-14.4-install/include \
    -std=c++11
```

### Example 2: Verilator Inverter

See `verilator-test/simple_inv.v` for Verilog source.

Auto-generate and build:
```bash
cd verilator-test
./verilog2xyce.pl -b -n simple_inv.v
/usr/local/xyce_patched/bin/Xyce simple_inv_test.cir
```

## Gnuplot Manual Plotting

For custom plots, create a `.gp` file:

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

## Tips

- Column 1 in .prn = Index
- Column 2 in .prn = TIME (always use this for x-axis)
- Columns 3+ = Your signals

- For multi-window plots, use `set multiplot`
- For log scale: `set logscale y`
- For different line styles: `ls 1`, `ls 2`, etc.
- Export formats: `png`, `pdf`, `svg`, `epslatex`

## References

- Xyce User Guide: https://xyce.sandia.gov/documentation/
- Verilator Manual: https://verilator.org/guide/latest/
- Gnuplot Documentation: http://gnuplot.info/docs_5.4/
