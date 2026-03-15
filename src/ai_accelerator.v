

module ai_accelerator #(
    parameter N = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter COORD_WIDTH = 16
)(
    input wire clk,
    input wire rst,
    input wire system_start,

    // Streaming Sensor Input (Radar/Camera)
    input wire [7:0] sensor_pixel_in,

    // Final Actionable Outputs for Interceptor
    output wire [COORD_WIDTH-1:0] target_pred_x,
    output wire [COORD_WIDTH-1:0] target_pred_y,
    output wire [COORD_WIDTH-1:0] target_pred_z,
    output wire intercept_ready
);

    // ==========================================
    // Internal Interconnect Wires
    // ==========================================
    
    // CNN -> Buffer
    wire cnn_valid;
    wire [7:0] flat_patch;
    wire [11:0] cnn_addr;
    wire cnn_mem_en;
    wire cnn_done;
    
    // Controller -> System
    wire ctrl_layer_start;
    wire [7:0] rom_w_addr;
    wire [7:0] rom_a_addr; // Connected to prevent warnings
    wire rom_en;
    
    // ROM -> Dense Layer
    wire [(N*DATA_WIDTH)-1:0] weight_bus;

    // Dense Layer -> ReLU
    wire dense_done;
    wire [(N*ACC_WIDTH)-1:0] dense_out_flat;
    
    // ReLU -> Graph Builder / Kalman
    wire [(N*ACC_WIDTH)-1:0] relu_out_flat;

    // ==========================================
    // Serial-to-Parallel CNN Buffer
    // Packs 8x 8-bit pixels into 1x 64-bit vector
    // ==========================================
    reg [63:0] patch_buffer;
    reg [2:0] patch_idx;
    reg buffer_full_trigger;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            patch_idx <= 0;
            patch_buffer <= 0;
            buffer_full_trigger <= 0;
        end else begin
            buffer_full_trigger <= 0; // Default pulse
            if (cnn_valid) begin
                patch_buffer[patch_idx*8 +: 8] <= flat_patch;
                if (patch_idx == 3'd7) begin
                    patch_idx <= 0;
                    buffer_full_trigger <= 1; // Fire the dense layer once 64-bits are ready
                end else begin
                    patch_idx <= patch_idx + 1;
                end
            end
        end
    end

    // ==========================================
    // 1. The Brain (Controller FSM)
    // ==========================================
    controller ctrl_inst (
        .clk(clk),
        .rst(rst),
        .start(buffer_full_trigger), // Triggered only when buffer is full
        .layer_start(ctrl_layer_start),
        .layer_done(dense_done),
        .w_addr(rom_w_addr),
        .a_addr(rom_a_addr), // Explicitly connected
        .mem_en(rom_en),
        .done() 
    );

    // ==========================================
    // 2. The Fuel (Weight ROM)
    // ==========================================
    weight_rom weights_inst (
        .clk(clk),
        .en(rom_en),
        .addr(rom_w_addr),
        .data_out(weight_bus)
    );

    // ==========================================
    // 3. Sensor Formatting (CNN Engine)
    // ==========================================
    cnn_engine cnn_inst (
        .clk(clk),
        .rst(rst),
        .start(system_start),
        .read_addr(cnn_addr),       // Fixed
        .mem_en(cnn_mem_en),        // Fixed
        .pixel_data(sensor_pixel_in),
        .valid_out(cnn_valid),
        .flat_patch_data(flat_patch),
        .done(cnn_done)             // Fixed
    );

    // ==========================================
    // 4. The Core Compute (Systolic Array Wrapper)
    // ==========================================
    dense_layer engine_inst (
        .clk(clk),
        .rst(rst),
        .start(ctrl_layer_start),
        .a_in_flat(patch_buffer), // Now feeding a full 64-bit vector
        .b_in_flat(weight_bus),
        .output_vector(dense_out_flat),
        .done(dense_done)
    );

    // ==========================================
    // 5. Activation (ReLU)
    // ==========================================
    relu activation_inst (
        .in_flat(dense_out_flat),
        .out_flat(relu_out_flat)
    );

    // ==========================================
    // 6. Target Interaction (Graph Builder)
    // ==========================================
    wire [63:0] adj_matrix;
    wire graph_done;
    
    graph_builder graph_inst (
        .clk(clk),
        .rst(rst),
        .start(dense_done),
        .target_coords_flat(relu_out_flat[127:0]), 
        .adj_matrix_flat(adj_matrix),
        .done(graph_done)
    );

    // ==========================================
    // 7. Trajectory Prediction (Kalman Filter)
    // ==========================================
    kalman_filter kf_x (
        .clk(clk),
        .rst(rst),
        .update_en(graph_done),
        .measured_pos(relu_out_flat[15:0]), 
        .est_pos(target_pred_x),
        .est_vel()
    );

    kalman_filter kf_y (
        .clk(clk),
        .rst(rst),
        .update_en(graph_done),
        .measured_pos(relu_out_flat[31:16]), 
        .est_pos(target_pred_y),
        .est_vel()
    );

    kalman_filter kf_z (
        .clk(clk),
        .rst(rst),
        .update_en(graph_done),
        .measured_pos(relu_out_flat[47:32]), 
        .est_pos(target_pred_z),
        .est_vel()
    );

    assign intercept_ready = graph_done;

endmodule