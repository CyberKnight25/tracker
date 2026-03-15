`timescale 1ns / 1ps


module mac #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
    )(
    input clk,
    input rst,
    input signed [DATA_WIDTH-1:0] a,
    input signed [DATA_WIDTH-1:0] b,
    
    input signed [ACC_WIDTH-1:0] acc_in,
    output reg signed [ACC_WIDTH-1:0] acc_out
    );
    
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            acc_out <= 0;
        end else begin
            // The core math: multiply and add in one clock cycle
            acc_out <= acc_in + (a * b);
        end
    end
endmodule
