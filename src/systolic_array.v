`timescale 1ns / 1ps

module systolic_array #(
    parameter N = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input clk,
    input rst,

    input  signed [N*DATA_WIDTH-1:0] a_in,
    input  signed [N*DATA_WIDTH-1:0] b_in,

    output signed [N*N*ACC_WIDTH-1:0] result
);

wire signed [DATA_WIDTH-1:0] a_vec [0:N-1];
wire signed [DATA_WIDTH-1:0] b_vec [0:N-1];

wire signed [DATA_WIDTH-1:0] a_bus [0:N-1][0:N-1];
wire signed [DATA_WIDTH-1:0] b_bus [0:N-1][0:N-1];

wire signed [ACC_WIDTH-1:0] psum [0:N-1][0:N-1];

genvar i,j;

generate
for(i=0;i<N;i=i+1) begin
    assign a_vec[i] = a_in[i*DATA_WIDTH +: DATA_WIDTH];
    assign b_vec[i] = b_in[i*DATA_WIDTH +: DATA_WIDTH];
end
endgenerate


generate
for(i=0;i<N;i=i+1) begin
    for(j=0;j<N;j=j+1) begin

        pe #(
            .DATA_WIDTH(DATA_WIDTH),
            .ACC_WIDTH(ACC_WIDTH)
        ) PE_inst (

            .clk(clk),
            .rst(rst),

            .a_in( (j==0) ? a_vec[i] : a_bus[i][j-1] ),
            .b_in( (i==0) ? b_vec[j] : b_bus[i-1][j] ),

            .psum_in( (j==0) ? 0 : psum[i][j-1] ),

            .a_out(a_bus[i][j]),
            .b_out(b_bus[i][j]),
            .psum_out(psum[i][j])

        );

        assign result[(i*N + j)*ACC_WIDTH +: ACC_WIDTH] = psum[i][j];

    end
end
endgenerate

endmodule