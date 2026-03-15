`timescale 1ns / 1ps

module tb_ai_accelerator;

    // Parameters (Matching the Top Module)
    parameter N = 8;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter COORD_WIDTH = 16;

    // Testbench Signals
    reg clk;
    reg rst;
    reg system_start;
    reg [7:0] sensor_pixel_in;

    // Output wires to monitor
    wire [COORD_WIDTH-1:0] target_pred_x;
    wire [COORD_WIDTH-1:0] target_pred_y;
    wire [COORD_WIDTH-1:0] target_pred_z;
    wire intercept_ready;

    // 1. Instantiate the Top Module (Device Under Test)
    ai_accelerator #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .COORD_WIDTH(COORD_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .system_start(system_start),
        .sensor_pixel_in(sensor_pixel_in),
        .target_pred_x(target_pred_x),
        .target_pred_y(target_pred_y),
        .target_pred_z(target_pred_z),
        .intercept_ready(intercept_ready)
    );

    // 2. Clock Generation (100 MHz -> 10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // 3. Main Simulation Sequence
    initial begin
        // Initialize signals
        rst = 1; // Active low reset
        system_start = 0;
        sensor_pixel_in = 8'd0;

        // Dump waveforms for Vivado / GTKWave
        $dumpfile("ai_accelerator_waves.vcd");
        $dumpvars(0, tb_ai_accelerator);

        $display("=== STARTING INTERCEPTOR SIMULATION ===");

        // Apply Reset
        #20;
        rst = 0; // Pull reset low
        #20;
        rst = 1; // Release reset
        #20;

        // Fire the start pulse
        $display("[%0t] Firing System Start...", $time);
        system_start = 1;
        #10;
        system_start = 0;

        // Simulate streaming in dummy sensor data
        // In reality, this would read from a synthetic_targets.csv
        repeat (64) begin
            @(posedge clk);
            sensor_pixel_in = sensor_pixel_in + 8'd3; // Just injecting changing dummy data
        end

        // Wait for the pipeline to flush
        // CNN + Systolic Array (3N-2) + Graph Builder + Kalman
        $display("[%0t] Waiting for pipeline latency...", $time);
        
        // Timeout watchdog or wait for the intercept_ready flag
        wait (intercept_ready == 1'b1);
        
        $display("[%0t] INTERCEPT SOLUTION READY!", $time);
        $display("Predicted X: %d", target_pred_x);
        $display("Predicted Y: %d", target_pred_y);
        $display("Predicted Z: %d", target_pred_z);

        // Let it run a few more clock cycles to observe stability
        #50;
        
        $display("=== SIMULATION COMPLETE ===");
        $finish;
    end
    
    // This will trigger the exact nanosecond the accelerator finishes, 
// regardless of what the sensor data loop is doing.
always @(posedge intercept_ready) begin
    $display("[%0t] INTERCEPT SOLUTION READY!", $time);
    $display("Predicted X: %d", target_pred_x);
    $display("Predicted Y: %d", target_pred_y);
    $display("Predicted Z: %d", target_pred_z);
    #50;
    $finish;
end

endmodule