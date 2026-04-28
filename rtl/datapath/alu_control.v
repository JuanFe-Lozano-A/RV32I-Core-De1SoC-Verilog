`timescale 1ns / 1ps

module alu_control (
    input wire [1:0] ALUOp,
    input wire [2:0] funct3,
    input wire funct7_5, // bit 5 of funct7
    output reg [3:0] op
);

    // ALU Operation Codes
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;
    localparam ALU_SLTU = 4'b0110;
    localparam ALU_SLL  = 4'b0111;
    localparam ALU_SRL  = 4'b1000;
    localparam ALU_SRA  = 4'b1001;

    always @(*) begin
        case (ALUOp)
            2'b00: op = ALU_ADD; // e.g., Load/Store/JALR/AUIPC/LUI
            2'b01: op = ALU_SUB; // e.g., Branch
            2'b10: begin // R-type
                case (funct3)
                    3'b000: op = (funct7_5) ? ALU_SUB : ALU_ADD;
                    3'b001: op = ALU_SLL;
                    3'b010: op = ALU_SLT;
                    3'b011: op = ALU_SLTU;
                    3'b100: op = ALU_XOR;
                    3'b101: op = (funct7_5) ? ALU_SRA : ALU_SRL;
                    3'b110: op = ALU_OR;
                    3'b111: op = ALU_AND;
                    default: op = ALU_ADD;
                endcase
            end
            2'b11: begin // I-type
                case (funct3)
                    3'b000: op = ALU_ADD;
                    3'b001: op = ALU_SLL;
                    3'b010: op = ALU_SLT;
                    3'b011: op = ALU_SLTU;
                    3'b100: op = ALU_XOR;
                    3'b101: op = (funct7_5) ? ALU_SRA : ALU_SRL;
                    3'b110: op = ALU_OR;
                    3'b111: op = ALU_AND;
                    default: op = ALU_ADD;
                endcase
            end
            default: op = ALU_ADD;
        endcase
    end

endmodule
