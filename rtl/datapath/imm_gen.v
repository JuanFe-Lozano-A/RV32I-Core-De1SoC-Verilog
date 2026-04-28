`timescale 1ns / 1ps

module imm_gen (
    input wire [31:7] inst,
    input wire [2:0] ImmSel,
    output reg [31:0] imm
);

    always @(*) begin
        case (ImmSel)
            3'b000: // I-type (e.g., ADDI, LW)
                imm = {{20{inst[31]}}, inst[31:20]};
                
            3'b001: // S-type (e.g., SW)
                imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
                
            3'b010: // B-type (e.g., BEQ)
                imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
                
            3'b011: // J-type (e.g., JAL)
                imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
                
            3'b100: // U-type (e.g., LUI, AUIPC)
                imm = {inst[31:12], 12'b0};

            default:
                imm = 32'b0;
        endcase
    end

endmodule
