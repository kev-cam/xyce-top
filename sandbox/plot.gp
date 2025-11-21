#!/usr/bin/gnuplot
# Gnuplot script for Xyce .prn files

set terminal png size 1200,800
set output 'output.png'

set title 'Xyce Simulation Results'
set xlabel 'Time (s)'
set ylabel 'Voltage (V)'
set grid

# Format x-axis for scientific notation
set format x "%.1e"

# Plot data (skip header, use columns: TIME, V(VDD), V(A), V(B))
plot 'inv.cir.prn' using 2:3 with lines title 'V(VDD)' lw 2, \
     '' using 2:4 with lines title 'V(A)' lw 2, \
     '' using 2:5 with lines title 'V(B)' lw 2
