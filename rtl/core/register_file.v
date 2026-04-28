`timescale 1ns / 1ps

module register_file (
    input wire clk,         // FPGA_CLK — synchronous writes only
    input wire we,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2,

    // History Buffer Interface
    input wire          restore_en,
    input wire [1023:0] restore_in,
    output wire [1023:0] state_out
);

    reg [31:0] registers [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'b0;
    end

    // -------------------------------------------------------
    // Read ports — purely combinational (single-cycle CPU)
    // x0 is hardwired to zero
    // -------------------------------------------------------
    assign rd1 = (rs1 == 5'd0) ? 32'd0 : registers[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'd0 : registers[rs2];

    // -------------------------------------------------------
    // State serialization for history buffer — combinational
    // -------------------------------------------------------
    genvar k;
    generate
        for (k = 0; k < 32; k = k + 1) begin : gen_state
            assign state_out[k*32 +: 32] = registers[k];
        end
    endgenerate

    // -------------------------------------------------------
    // Synchronous Write / Restore
    //
    // WHY SYNCHRONOUS: The async latch version had a critical bug on FPGA
    // hardware — the 'rd' signal (combinational decode of instruction bits)
    // can transiently glitch to other register indices while 'we' is high
    // (one full clock cycle). This caused spurious writes to registers like
    // x3, corrupting the return address and causing wrong jumps (0x54 loop).
    //
    // With posedge clk writes, 'rd' and 'wd' are sampled exactly once at
    // the clock edge, when both are fully settled. No glitches possible.
    // -------------------------------------------------------
    integer j;
    always @(posedge clk) begin
        if (restore_en) begin
            for (j = 0; j < 32; j = j + 1) begin
                if (j == 0) registers[0] <= 32'b0;
                else        registers[j] <= restore_in[j*32 +: 32];
            end
        end else if (we && rd != 5'd0) begin
            registers[rd] <= wd;
        end
    end

endmodule
