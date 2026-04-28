`timescale 1ns / 1ps

module register_file (
    // NOTE: No clock. Writes are asynchronous (latch-based).
    // The FPGA system clock is only used by the Program Counter.
    input wire we,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2,

    // History Buffer Interface
    input wire restore_en,
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
    // Read ports — purely combinational, unchanged
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
    // Async Write / Restore (Latch-based)
    //
    // Priority: restore_en > we
    // When neither is asserted, all registers hold their value
    // (latch retention). Quartus infers 32 enabled latches.
    //
    // x0 is never written — it is always 0 on the read ports
    // via the rd1/rd2 assigns above. For restore, we explicitly
    // keep registers[0] = 0 to keep state_out[31:0] correct.
    // -------------------------------------------------------
    integer j;
    always @(*) begin
        if (restore_en) begin
            for (j = 0; j < 32; j = j + 1) begin
                if (j == 0) registers[0] = 32'b0;
                else        registers[j] = restore_in[j*32 +: 32];
            end
        end else if (we && rd != 5'd0) begin
            registers[rd] = wd;
        end
    end

endmodule
