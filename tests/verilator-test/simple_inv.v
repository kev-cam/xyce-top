// Simple inverter module for Verilator testing
module simple_inv(
    input  wire in,
    output wire out
);

    not (out, in);

endmodule
