`timescale 1ns / 1ps

module relu #(
    parameter N = 8,
    parameter ACC_WIDTH = 32
)(
    input  [N*ACC_WIDTH-1:0] in_flat,
    output [N*ACC_WIDTH-1:0] out_flat
);

    genvar i;
    generate
        for(i = 0; i < N; i = i + 1) begin : relu_gen
            // Added 'signed' to ensure the sign bit is respected properly
            wire signed [ACC_WIDTH-1:0] current_val = in_flat[i*ACC_WIDTH +: ACC_WIDTH];

            // Multiplexer: If MSB (bit 31) is 1, output 0. Else, pass the value.
            assign out_flat[i*ACC_WIDTH +: ACC_WIDTH] = current_val[ACC_WIDTH-1] ? {ACC_WIDTH{1'b0}} : current_val;
        end
    endgenerate

endmodule