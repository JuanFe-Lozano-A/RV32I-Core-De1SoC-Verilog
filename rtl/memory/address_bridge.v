`timescale 1ns / 1ps

module address_bridge (
    input wire [31:0] addr,
    input wire MemRead,
    input wire MemWrite,
    
    // RAM Interface
    output wire ram_sel,
    input wire [31:0] ram_rdata,
    
    // IO/Peripheral Interface
    output wire io_sel,
    input wire [31:0] io_rdata,
    
    // Output to CPU Core
    output reg [31:0] rdata_out
);

    // Memory Map:
    // 0x0000_0000 - 0x0000_1FFF : RAM (8KB)
    // 0x0000_2000 - 0x0000_2FFF : I/O space

    assign ram_sel = (addr < 32'h00002000) ? 1'b1 : 1'b0;
    assign io_sel  = (addr >= 32'h00002000 && addr < 32'h00003000) ? 1'b1 : 1'b0;

    always @(*) begin
        if (MemRead) begin
            if (ram_sel) begin
                rdata_out = ram_rdata;
            end else if (io_sel) begin
                rdata_out = io_rdata;
            end else begin
                rdata_out = 32'h00000000; // Reserved / Unmapped space
            end
        end else begin
            rdata_out = 32'h00000000;
        end
    end

endmodule
