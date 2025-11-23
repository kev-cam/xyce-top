// Simple inverter module for Verilator testing
module simple_inv(
    input  wire in,
    output wire out
);

    assign out = ~in;

endmodule
