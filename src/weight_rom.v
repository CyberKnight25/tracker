`timescale 1ns / 1ps

module weight_rom #(
    parameter N = 8,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,  // 8-bit address = 256 rows of weights
    parameter INIT_FILE = "weights.mem" // The file exported by your Python script
)(
    input  wire clk,
    input  wire en,
    input  wire [ADDR_WIDTH-1:0] addr,
    output reg  [N*DATA_WIDTH-1:0] data_out
);

    // Declare the memory array
    // Width = 64 bits (8 weights per row), Depth = 256 rows
    reg [N*DATA_WIDTH-1:0] rom [0:(1<<ADDR_WIDTH)-1];

    // Initialize the memory from the external hex file
    initial begin
        $readmemh(INIT_FILE, rom);
    end

    // Synchronous read (Required for Vivado to infer BRAM)
    always @(posedge clk) begin
        if (en) begin
            data_out <= rom[addr];
        end
    end

endmodule