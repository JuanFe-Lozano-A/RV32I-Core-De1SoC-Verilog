`timescale 1ns / 1ps

module data_memory (
    // NOTE: No clock. Both reads and writes are fully asynchronous (latch-based).
    input wire we,
    input wire re,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire [3:0]  be,
    output reg [31:0] rdata
);

    // 128 bytes of data RAM, organized as four independent 8-bit byte-lane banks.
    // This mirrors how physical SRAM with byte-enables works:
    //
    //   bank3  bank2  bank1  bank0
    //  [31:24][23:16][15:8] [7:0]
    //
    // LB/SB: writes or reads exactly ONE bank, selected by addr[1:0]
    // LH/SH: writes or reads TWO adjacent banks, selected by addr[1]
    // LW/SW: accesses ALL FOUR banks simultaneously
    //
    // The byte-enable signals (be[3:0]) from rv32i_core.v already encode
    // which banks to activate — no additional decoding is needed here.
    reg [7:0] bank0 [0:31]; // bits  7:0
    reg [7:0] bank1 [0:31]; // bits 15:8
    reg [7:0] bank2 [0:31]; // bits 23:16
    reg [7:0] bank3 [0:31]; // bits 31:24
    // Note: No 'initial' block. Cyclone V logic elements default to 0 at
    // FPGA configuration, and 'initial' blocks on latch arrays cause
    // Quartus error 276000 (Cannot synthesize initialized RAM logic).

    // Word address: strip byte offset bits [1:0] and upper bits.
    // 32 words requires a 5-bit index: addr[6:2]
    wire [4:0] word_addr = addr[6:2];

    // -------------------------------------------------------
    // Async Write (Latch-based)
    // Each bank is independently gated by its byte-enable bit.
    // Quartus infers these as enabled latches — one per byte lane.
    // -------------------------------------------------------
    always @(*) begin
        if (we) begin
            if (be[0]) bank0[word_addr] = wdata[7:0];
            if (be[1]) bank1[word_addr] = wdata[15:8];
            if (be[2]) bank2[word_addr] = wdata[23:16];
            if (be[3]) bank3[word_addr] = wdata[31:24];
        end
    end

    // -------------------------------------------------------
    // Async Read (Combinational)
    // Always assembles the full 32-bit word from all four banks.
    // The CPU extracts the relevant bytes (LB/LH/LBU/LHU)
    // via aligned_rdata logic in rv32i_core.v.
    // -------------------------------------------------------
    always @(*) begin
        if (re)
            rdata = {bank3[word_addr], bank2[word_addr],
                     bank1[word_addr], bank0[word_addr]};
        else
            rdata = 32'h00000000;
    end

endmodule
