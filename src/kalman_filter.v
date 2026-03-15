`timescale 1ns / 1ps

module kalman_filter #(
    parameter WIDTH = 16,
    // Using bit-shifts instead of multipliers for the Kalman Gains.
    // Shift by 2 = dividing by 4 (Alpha = 0.25)
    // Shift by 4 = dividing by 16 (Beta = 0.0625)
    parameter ALPHA_SHIFT = 2, 
    parameter BETA_SHIFT  = 4  
)(
    input wire clk,
    input wire rst,
    input wire update_en,               // High when a new coordinate arrives from the GNN/CNN
    input wire signed [WIDTH-1:0] measured_pos, // The new sensor reading
    
    output reg signed [WIDTH-1:0] est_pos,      // The filtered, smoothed position
    output reg signed [WIDTH-1:0] est_vel       // The predicted velocity vector
);

    // Combinational wires for pure, 0-cycle math
    wire signed [WIDTH-1:0] pred_pos;
    wire signed [WIDTH-1:0] error;
    wire signed [WIDTH-1:0] pos_correction;
    wire signed [WIDTH-1:0] vel_correction;

    // 1. Predict Step (Assuming dT = 1 frame tick for discrete time)
    assign pred_pos = est_pos + est_vel;

    // 2. Innovation Step (Calculate the residual error)
    assign error = measured_pos - pred_pos;

    // 3. Apply Kalman Gains via Arithmetic Right Shift (>>> preserves the sign bit in V2001)
    assign pos_correction = error >>> ALPHA_SHIFT;
    assign vel_correction = error >>> BETA_SHIFT;

    // 4. Update Step (Clocked State Registers)
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            est_pos <= 0;
            est_vel <= 0;
        end else if (update_en) begin
            // Lock in the new corrected trajectory
            est_pos <= pred_pos + pos_correction;
            est_vel <= est_vel + vel_correction;
        end
    end

endmodule