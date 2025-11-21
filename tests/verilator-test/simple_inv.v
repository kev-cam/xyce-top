// Simple combinational inverter for analog-digital co-simulation
module simple_inv (
    input wire in,
    output wire out
);

    assign out = ~in;

endmodule
