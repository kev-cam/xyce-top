// 2-input NAND gate module for Verilator testing
module nand2(
    input  wire a,
    input  wire b,
    output wire out
);

    nand (out, a, b);

endmodule
