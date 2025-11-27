#!/usr/bin/perl -s

$prn = $ARGV[0];
$png = $ARGV[1];

$max=3.5;
$min=-0.5;

open(PRN,"<$prn");

$head = <PRN>;
@cols = split(/\s+/,$head);

open(GPL,"| gnuplot");
while(<PRN>) {
    @vals = split(/\s+/,$_);
#    print TMP;
}
close(TMP);

$n=$#cols; $n++;

print GPL
    "set terminal png\n",
    "set output '$png'\n",
    "set yrange [${min}:$max]\n",
    "set xlabel 'Time'\n",
    "set ylabel 'Voltage'\n",
    "plot for[col=3:$n] '$prn' using 2:col title columnheader(col) with lines\n";
      
