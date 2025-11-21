#!/bin/bash
# Quick plotter for Xyce .prn files

if [ $# -lt 1 ]; then
    echo "Usage: $0 <file.prn> [output.png]"
    echo ""
    echo "Examples:"
    echo "  $0 inv.cir.prn                    # Creates inv.cir.png"
    echo "  $0 inv.cir.prn myplot.png         # Creates myplot.png"
    echo "  $0 inv.cir.prn                    # Interactive mode (hit 'q' to quit)"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-${INPUT_FILE%.prn}.png}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found"
    exit 1
fi

# Read header to get column names
HEADER=$(head -1 "$INPUT_FILE")
COLUMNS=($HEADER)

# Generate gnuplot script
cat > /tmp/plot_xyce_$$.gp << 'EOF'
set terminal png size 1200,800
set output 'OUTPUT_FILE'

set title 'Xyce Simulation: INPUT_FILE'
set xlabel 'Time (s)'
set ylabel 'Voltage (V)'
set grid
set key outside right

# Format axes
set format x "%.1e"
set format y "%.2f"

# Auto-generate plot commands for all voltage columns (skip Index and TIME)
plot \
EOF

# Build plot commands dynamically
PLOT_CMD=""
COL_NUM=1
for col in "${COLUMNS[@]}"; do
    if [[ $col == V\(* ]]; then
        if [ -n "$PLOT_CMD" ]; then
            PLOT_CMD="$PLOT_CMD, \\\\\n     "
        fi
        PLOT_CMD="${PLOT_CMD}'INPUT_FILE' using 2:$COL_NUM with lines title '$col' lw 2"
    fi
    ((COL_NUM++))
done

echo -e "$PLOT_CMD" >> /tmp/plot_xyce_$$.gp

# Replace placeholders
sed -i "s|INPUT_FILE|$INPUT_FILE|g" /tmp/plot_xyce_$$.gp
sed -i "s|OUTPUT_FILE|$OUTPUT_FILE|g" /tmp/plot_xyce_$$.gp

# Run gnuplot
gnuplot /tmp/plot_xyce_$$.gp

if [ $? -eq 0 ]; then
    echo "Plot saved to: $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
else
    echo "Error generating plot"
    exit 1
fi

# Cleanup
rm -f /tmp/plot_xyce_$$.gp
