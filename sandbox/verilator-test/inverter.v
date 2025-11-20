// Simple inverter with delay
module inverter #(
    parameter real DELAY = 5e-12,  // 5ps delay
    parameter real RISE_TIME = 3e-12,
    parameter real FALL_TIME = 2e-12
) (
    input wire vdd,
    input wire in,
    output reg out
);

    real vdd_real, in_real, out_real;
    real last_transition_time;
    real target_value;
    integer transitioning;

    initial begin
        out_real = 0.0;
        out = 1'b0;
        last_transition_time = 0.0;
        transitioning = 0;
        target_value = 0.0;
    end

    // Convert logic to real voltages
    always @(*) begin
        vdd_real = vdd ? 3.0 : 0.0;
        in_real = in ? 3.0 : 0.0;
    end

    // Inverter logic with delay
    always @(in_real or vdd_real) begin
        real threshold, new_target;
        threshold = vdd_real / 2.0;

        if (vdd_real > 0.1) begin
            // Determine new target output
            if (in_real > threshold) begin
                new_target = 0.0;  // Input high -> output low
            end else begin
                new_target = vdd_real;  // Input low -> output high
            end

            // Start transition if target changes
            if (new_target != target_value) begin
                target_value = new_target;
                transitioning = 1;
                last_transition_time = $realtime;
            end
        end else begin
            out_real = 0.0;
        end
    end

    // Update output with slew rate
    always @(posedge $global_clock) begin
        if (transitioning) begin
            real elapsed, transition_time, delta;
            elapsed = $realtime - last_transition_time;

            // Choose rise or fall time
            transition_time = (target_value > out_real) ? RISE_TIME : FALL_TIME;

            if (elapsed >= DELAY + transition_time) begin
                out_real = target_value;
                transitioning = 0;
            end else if (elapsed >= DELAY) begin
                delta = (target_value - out_real) * (elapsed - DELAY) / transition_time;
                out_real = out_real + delta;
            end
        end

        // Convert real to logic
        out = (out_real > 1.5) ? 1'b1 : 1'b0;
    end

endmodule
