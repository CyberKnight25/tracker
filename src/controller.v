`timescale 1ns / 1ps

module controller #(
    parameter ADDR_WIDTH = 8,
    parameter NUM_ROWS = 8  // 8 rows for an 8x8 matrix
)(
    input wire clk,
    input wire rst,
    input wire start,

    // To/From Compute Engine (dense_layer)
    output reg layer_start,
    input wire layer_done,

    // To Memories (weight_rom & activation bram)
    output reg [ADDR_WIDTH-1:0] w_addr,
    output reg [ADDR_WIDTH-1:0] a_addr,
    output reg mem_en,

    // Global Status
    output reg done
);

    // V2001 State Encoding
    parameter S_IDLE   = 3'd0;
    parameter S_STREAM = 3'd1;
    parameter S_WAIT   = 3'd2;
    parameter S_DONE   = 3'd3;

    reg [2:0] state, next_state;
    reg [ADDR_WIDTH-1:0] row_cnt;

    // 1. State Register (Sequential)
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // 2. Next State Logic (Combinational)
    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            S_IDLE: begin
                if (start) next_state = S_STREAM;
            end
            S_STREAM: begin
                // Stream data for NUM_ROWS cycles
                if (row_cnt == NUM_ROWS - 1) next_state = S_WAIT;
            end
            S_WAIT: begin
                // Wait for the pipeline to flush
                if (layer_done) next_state = S_DONE;
            end
            S_DONE: begin
                next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // 3. Output & Counter Logic (Sequential to prevent glitches)
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            layer_start <= 0;
            w_addr <= 0;
            a_addr <= 0;
            mem_en <= 0;
            row_cnt <= 0;
            done <= 0;
        end else begin
            // Default pulse assignments
            layer_start <= 0;
            done <= 0;

            case (state)
                S_IDLE: begin
                    row_cnt <= 0;
                    w_addr <= 0; // Reset address pointers
                    a_addr <= 0;
                    mem_en <= 0;
                end

                S_STREAM: begin
                    mem_en <= 1;
                    
                    // Fire the start signal to the dense_layer on the very first streaming cycle
                    if (row_cnt == 0) begin
                        layer_start <= 1; 
                    end

                    // March down the memory rows
                    w_addr <= w_addr + 1;
                    a_addr <= a_addr + 1;
                    row_cnt <= row_cnt + 1;
                end

                S_WAIT: begin
                    mem_en <= 0; // Stop reading memory, save power
                end

                S_DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule