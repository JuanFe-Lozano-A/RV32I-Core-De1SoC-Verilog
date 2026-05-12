`timescale 1ns / 1ps

/**
 * Unified Memory (Dual-Port RAM) - Optimized for Synthesis
 * 
 * This module combines instruction and data storage into a single 32-bit array.
 * This structure is preferred by Quartus for reliable RAM inference and initialization.
 */
module unified_memory (
    input wire clk,
    
    // Port A: Instruction Fetch (Read-Only)
    input wire [31:0] addr_a,
    output wire [31:0] inst_out,
    
    // Port B: Data Access (Read/Write)
    input wire [31:0] addr_b,
    input wire [31:0] wdata_b,
    input wire [3:0]  be_b,
    input wire        we_b,
    input wire        re_b,
    output reg [31:0] data_out_b,
    
    // History Buffer Interface (Rollback for Data portion: words 32-63)
    input wire          restore_en,
    input wire [1023:0] restore_data,
    output wire [1023:0] state_out
);

    // 256 bytes total (64 words).
    reg [31:0] mem [0:63];

    integer i;
    initial begin
        // Standard initialization
        for (i = 0; i < 64; i = i + 1) begin
            mem[i] = 32'h00000000;
        end
        // Load the unified hex file (Code + Data)
        $readmemh("program.hex", mem);
    end

    // Word addresses (truncated to 64-word range)
    wire [5:0] word_addr_a = addr_a[7:2];
    wire [5:0] word_addr_b = addr_b[7:2];

    // -------------------------------------------------------
    // Port A: Asynchronous Instruction Read
    // -------------------------------------------------------
    assign inst_out = mem[word_addr_a];

    // -------------------------------------------------------
    // Port B: Asynchronous Data Read
    // -------------------------------------------------------
    always @(*) begin
        if (re_b)
            data_out_b = mem[word_addr_b];
        else
            data_out_b = 32'h00000000;
    end

    // -------------------------------------------------------
    // Port B: Synchronous Write / History Restore
    // -------------------------------------------------------
    integer k;
    always @(posedge clk) begin
        if (restore_en) begin
            // Restore only the data portion (words 32-63)
            for (k = 0; k < 32; k = k + 1) begin
                mem[k+32] <= restore_data[k*32 +: 32];
            end
        end else if (we_b) begin
            // Byte-enable logic for partial writes (SB, SH, SW)
            if (be_b[0]) mem[word_addr_b][7:0]   <= wdata_b[7:0];
            if (be_b[1]) mem[word_addr_b][15:8]  <= wdata_b[15:8];
            if (be_b[2]) mem[word_addr_b][23:16] <= wdata_b[23:16];
            if (be_b[3]) mem[word_addr_b][31:24] <= wdata_b[31:24];
        end
    end

    // -------------------------------------------------------
    // State serialization for History Buffer (Snapshots words 32-63)
    // -------------------------------------------------------
    genvar m;
    generate
        for (m = 0; m < 32; m = m + 1) begin : gen_mem_state
            assign state_out[m*32 +: 32] = mem[m+32];
        end
    endgenerate

endmodule
