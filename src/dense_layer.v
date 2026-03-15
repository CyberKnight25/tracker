`timescale 1ns / 1ps

module dense_layer #(
    parameter N = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input clk,
    input rst,
    input start,

    // Streamed inputs
    input  signed [N*DATA_WIDTH-1:0] a_in_flat,
    input  signed [N*DATA_WIDTH-1:0] b_in_flat,

    // Captured output vector
    output reg signed [N*ACC_WIDTH-1:0] output_vector,
    output reg done
);

    // 1. Unpack flat inputs
    wire signed [DATA_WIDTH-1:0] a_vec [0:N-1];
    wire signed [DATA_WIDTH-1:0] b_vec [0:N-1];
    
    genvar i;
    generate
        for(i=0; i<N; i=i+1) begin : unpack_inputs
            assign a_vec[i] = a_in_flat[i*DATA_WIDTH +: DATA_WIDTH];
            assign b_vec[i] = b_in_flat[i*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    // 2. The Skewing Shift Registers
    // V2001: Integers declared at module level
    integer k, idx;
    
    reg signed [DATA_WIDTH-1:0] a_skew [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] b_skew [0:N-1][0:N-1];
    
    wire signed [N*DATA_WIDTH-1:0] a_array_in;
    wire signed [N*DATA_WIDTH-1:0] b_array_in;
    wire signed [N*N*ACC_WIDTH-1:0] array_result_flat;

    generate
        for(i=0; i<N; i=i+1) begin : pack_outputs
            // Route the diagonal of the skew registers to the array pins
            assign a_array_in[i*DATA_WIDTH +: DATA_WIDTH] = a_skew[i][i];
            assign b_array_in[i*DATA_WIDTH +: DATA_WIDTH] = b_skew[i][i];
        end
    endgenerate

    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            for(idx=0; idx<N; idx=idx+1) begin
                for(k=0; k<N; k=k+1) begin
                    a_skew[idx][k] <= 0;
                    b_skew[idx][k] <= 0;
                end
            end
        end else begin
            // Shift data in
            for(idx=0; idx<N; idx=idx+1) begin
                a_skew[idx][0] <= a_vec[idx];
                b_skew[idx][0] <= b_vec[idx];
                for(k=1; k<N; k=k+1) begin
                    a_skew[idx][k] <= a_skew[idx][k-1];
                    b_skew[idx][k] <= b_skew[idx][k-1];
                end
            end
        end
    end

    // 3. Instantiate the 8x8 array
    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) array_inst (
        .clk(clk),
        .rst(rst),
        .a_in(a_array_in),
        .b_in(b_array_in),
        .result(array_result_flat) 
    );

    // 4. Cycle Counter & Output Capture
    reg [7:0] cycle_cnt;
    reg active;

    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            done <= 0;
            output_vector <= 0;
            cycle_cnt <= 0;
            active <= 0;
        end
        else begin
            if(start) begin
                active <= 1;
                cycle_cnt <= 0;
                done <= 0;
            end
            
            if(active) begin
                cycle_cnt <= cycle_cnt + 1;
                
                // Pipeline depth for complete flush
                if(cycle_cnt == (3*N - 2)) begin
                    active <= 0;
                    done <= 1;
                    
                    // Capture valid bottom row
                    for(idx=0; idx<N; idx=idx+1) begin
                        output_vector[idx*ACC_WIDTH +: ACC_WIDTH] <= 
                            array_result_flat[((N-1)*N + idx)*ACC_WIDTH +: ACC_WIDTH];
                    end
                end
            end else begin
                done <= 0; 
            end
        end
    end

endmodule