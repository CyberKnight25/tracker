`timescale 1ns / 1ps

module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input clk,
    input rst,

    input  signed [DATA_WIDTH-1:0] a_in,
    input  signed [DATA_WIDTH-1:0] b_in,
    input  signed [ACC_WIDTH-1:0] psum_in,

    output reg signed [DATA_WIDTH-1:0] a_out,
    output reg signed [DATA_WIDTH-1:0] b_out,
    output signed [ACC_WIDTH-1:0] psum_out
);

wire signed [ACC_WIDTH-1:0] mac_result;

mac mac_unit (
    .clk(clk),
    .rst(rst),
    .a(a_in),
    .b(b_in),
    .acc_in(psum_in),
    .acc_out(mac_result)
);

assign psum_out = mac_result;

always @(posedge clk or negedge rst) begin
    if(!rst) begin
        a_out <= 0;
        b_out <= 0;
    end
    else begin
        a_out <= a_in;
        b_out <= b_in;
    end
end

endmodule