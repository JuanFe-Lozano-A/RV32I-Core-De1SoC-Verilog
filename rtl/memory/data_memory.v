`timescale 1ns / 1ps

module data_memory (
    input wire clk,         // FPGA_CLK — synchronous writes only
    input wire we,
    input wire re,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire [3:0]  be,
    output reg [31:0] rdata,

    // History Buffer Restore Interface
    input wire          restore_en,
    input wire [1023:0] restore_data,
    output wire [1023:0] state_out
);

    // 128 bytes organized as four independent 8-bit byte-lane banks.
    reg [7:0] bank0 [0:31];
    reg [7:0] bank1 [0:31];
    reg [7:0] bank2 [0:31];
    reg [7:0] bank3 [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            bank0[i] = 8'h00;
            bank1[i] = 8'h00;
            bank2[i] = 8'h00;
            bank3[i] = 8'h00;
        end
    end

    // Word address: byte address / 4
    wire [4:0] word_addr = addr[6:2];

    // -------------------------------------------------------
    // State serialization: word i = {bank3[i],bank2[i],bank1[i],bank0[i]}
    // -------------------------------------------------------
    genvar m;
    generate
        for (m = 0; m < 32; m = m + 1) begin : gen_mem_state
            assign state_out[m*32 +: 32] = {bank3[m], bank2[m], bank1[m], bank0[m]};
        end
    endgenerate

    // -------------------------------------------------------
    // Synchronous Write / Restore (posedge clk)
    // Reads remain asynchronous (combinational) for single-cycle operation.
    // -------------------------------------------------------
    integer ri;
    always @(posedge clk) begin
        if (restore_en) begin
            for (ri = 0; ri < 32; ri = ri + 1) begin
                bank0[ri] <= restore_data[ri*32 +: 8];
                bank1[ri] <= restore_data[ri*32+8  +: 8];
                bank2[ri] <= restore_data[ri*32+16 +: 8];
                bank3[ri] <= restore_data[ri*32+24 +: 8];
            end
        end else if (we) begin
            if (be[0]) bank0[word_addr] <= wdata[7:0];
            if (be[1]) bank1[word_addr] <= wdata[15:8];
            if (be[2]) bank2[word_addr] <= wdata[23:16];
            if (be[3]) bank3[word_addr] <= wdata[31:24];
        end
    end

    // -------------------------------------------------------
    // Async Read (Combinational — required for single-cycle CPU)
    // -------------------------------------------------------
    always @(*) begin
        if (re)
            rdata = {bank3[word_addr], bank2[word_addr],
                     bank1[word_addr], bank0[word_addr]};
        else
            rdata = 32'h00000000;
    end

endmodule
