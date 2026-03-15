`timescale 1ns / 1ps

module cnn_engine #(
    parameter IMG_WIDTH = 32,
    parameter KERNEL_SIZE = 3,
    parameter ADDR_WIDTH = 12
)(
    input wire clk,
    input wire rst,
    input wire start,

    // Interface to Sensor BRAM (The raw image/radar data)
    output reg [ADDR_WIDTH-1:0] read_addr,
    output reg mem_en,
    input wire [7:0] pixel_data,

    // Interface to the Dense Engine (Feeding the systolic array)
    output reg valid_out,
    output reg [7:0] flat_patch_data,
    
    output reg done
);

    // V2001 State Machine
    parameter S_IDLE  = 2'd0;
    parameter S_READ  = 2'd1;
    parameter S_DONE  = 2'd2;

    reg [1:0] state;
    
    // Counters for the sliding window
    reg [7:0] x_pos, y_pos;     // Where is the top-left of our window?
    reg [3:0] k_x, k_y;         // Where are we inside the 3x3 kernel?

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= S_IDLE;
            read_addr <= 0;
            mem_en <= 0;
            valid_out <= 0;
            flat_patch_data <= 0;
            done <= 0;
            x_pos <= 0; y_pos <= 0;
            k_x <= 0; k_y <= 0;
        end else begin
            // Default pulse
            valid_out <= 0;
            done <= 0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        state <= S_READ;
                        mem_en <= 1;
                        x_pos <= 0; y_pos <= 0;
                        k_x <= 0; k_y <= 0;
                    end
                end

                S_READ: begin
                    // 1. Calculate the flat memory address for the current pixel in the 3x3 patch
                    // Address = (y_pos + k_y) * IMG_WIDTH + (x_pos + k_x)
                    read_addr <= (y_pos + k_y) * IMG_WIDTH + (x_pos + k_x);
                    
                    // 2. The data arriving from BRAM gets passed to the dense layer
                    flat_patch_data <= pixel_data;
                    valid_out <= 1; // Tells the dense layer this is valid im2col data

                    // 3. Move the kernel window
                    if (k_x == KERNEL_SIZE - 1) begin
                        k_x <= 0;
                        if (k_y == KERNEL_SIZE - 1) begin
                            k_y <= 0;
                            // The 3x3 patch is finished. Move to the next pixel in the image.
                            if (x_pos == IMG_WIDTH - KERNEL_SIZE) begin
                                x_pos <= 0;
                                if (y_pos == IMG_WIDTH - KERNEL_SIZE) begin
                                    // Whole image is processed
                                    state <= S_DONE;
                                    mem_en <= 0;
                                end else begin
                                    y_pos <= y_pos + 1;
                                end
                            end else begin
                                x_pos <= x_pos + 1;
                            end
                        end else begin
                            k_y <= k_y + 1;
                        end
                    end else begin
                        k_x <= k_x + 1;
                    end
                end

                S_DONE: begin
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule