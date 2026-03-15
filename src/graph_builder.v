`timescale 1ns / 1ps

module graph_builder #(
    parameter N = 8,                // 8 Targets
    parameter COORD_WIDTH = 16,     // 16-bit X, Y coordinates
    parameter DIST_THRESH = 16'd500 // Threshold for "interacting" threats
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    
    // Flat input vector containing X, Y coordinates for all N targets
    // Format: {X7, Y7, X6, Y6, ... X0, Y0}
    input  wire [(N * COORD_WIDTH * 2) - 1:0] target_coords_flat,
    
    // 8x8 Adjacency matrix output (flattened to 64 bits)
    output reg [(N * N) - 1:0] adj_matrix_flat,
    output reg done
);

    // Unpack coordinates
    wire signed [COORD_WIDTH-1:0] x_vec [0:N-1];
    wire signed [COORD_WIDTH-1:0] y_vec [0:N-1];
    
    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : unpack_coords
            assign x_vec[i] = target_coords_flat[(i * 2 * COORD_WIDTH) + COORD_WIDTH +: COORD_WIDTH];
            assign y_vec[i] = target_coords_flat[(i * 2 * COORD_WIDTH) +: COORD_WIDTH];
        end
    endgenerate

    // Combinational Distance Calculation Matrix
    wire signed [COORD_WIDTH:0] dx [0:N-1][0:N-1];
    wire signed [COORD_WIDTH:0] dy [0:N-1][0:N-1];
    wire [COORD_WIDTH-1:0] abs_dx [0:N-1][0:N-1];
    wire [COORD_WIDTH-1:0] abs_dy [0:N-1][0:N-1];
    wire [COORD_WIDTH:0] manhattan_dist [0:N-1][0:N-1];
    wire adj_bit [0:N-1][0:N-1];

    generate
        for (i = 0; i < N; i = i + 1) begin : row_calc
            for (j = 0; j < N; j = j + 1) begin : col_calc
                // 1. Difference
                assign dx[i][j] = x_vec[i] - x_vec[j];
                assign dy[i][j] = y_vec[i] - y_vec[j];
                
                // 2. Absolute Value (Two's complement inversion if negative)
                assign abs_dx[i][j] = (dx[i][j] < 0) ? -dx[i][j] : dx[i][j];
                assign abs_dy[i][j] = (dy[i][j] < 0) ? -dy[i][j] : dy[i][j];
                
                // 3. Manhattan Distance
                assign manhattan_dist[i][j] = abs_dx[i][j] + abs_dy[i][j];
                
                // 4. Threshold comparison (1 if interacting or self, 0 if far)
                // 4. Threshold comparison (0 if self, 1 if interacting, 0 if far)
                assign adj_bit[i][j] = (i == j) ? 1'b0 : ((manhattan_dist[i][j] < DIST_THRESH) ? 1'b1 : 1'b0);
            end
        end
    endgenerate

    // Module-level integer for the always block (V2001)
    integer idx, jdx;

    // Register the outputs to maintain high clock speeds
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            adj_matrix_flat <= 0;
            done <= 0;
        end else begin
            if (start) begin
                for (idx = 0; idx < N; idx = idx + 1) begin
                    for (jdx = 0; jdx < N; jdx = jdx + 1) begin
                        adj_matrix_flat[(idx * N) + jdx] <= adj_bit[idx][jdx];
                    end
                end
                done <= 1;
            end else begin
                done <= 0;
            end
        end
    end

endmodule