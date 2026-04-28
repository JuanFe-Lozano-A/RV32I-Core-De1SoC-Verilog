`timescale 1ns / 1ps

module control_unit (
    input wire [6:0] opcode,
    output reg Branch,
    output reg Jump,
    output reg JALR_flag,
    output reg MemRead,
    output reg MemToReg,
    output reg [1:0] ALUOp,
    output reg MemWrite,
    output reg ALUSrc,
    output reg [1:0] ALUSrcA,
    output reg RegWrite,
    output reg [2:0] ImmSel,
    output reg Syscall,
    output reg Rs1Valid,
    output reg Rs2Valid,
    output reg IllegalInst
);

    // Opcodes
    localparam R_TYPE = 7'b0110011;
    localparam I_TYPE = 7'b0010011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;
    localparam LUI    = 7'b0110111;
    localparam AUIPC  = 7'b0010111;
    localparam SYSTEM = 7'b1110011;
    localparam FENCE  = 7'b0001111; // Memory ordering: NOP on single-cycle CPU

    always @(*) begin
        // Default values
        Branch   = 1'b0;
        Jump     = 1'b0;
        JALR_flag = 1'b0;
        MemRead  = 1'b0;
        MemToReg = 1'b0;
        ALUOp    = 2'b00;
        MemWrite = 1'b0;
        ALUSrc   = 1'b0;
        ALUSrcA  = 2'b00; // 00: rs1, 01: PC, 10: 0
        RegWrite = 1'b0;
        ImmSel   = 3'b000;
        Syscall  = 1'b0;
        Rs1Valid = 1'b0;
        Rs2Valid = 1'b0;
        IllegalInst = 1'b0;

        case (opcode)
            R_TYPE: begin
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
                Rs1Valid = 1'b1;
                Rs2Valid = 1'b1;
            end
            I_TYPE: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                ImmSel   = 3'b000; // I-type
                ALUOp    = 2'b11;  // I-type ALU
                Rs1Valid = 1'b1;
            end
            LOAD: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                MemRead  = 1'b1;
                MemToReg = 1'b1;
                ImmSel   = 3'b000; // I-type immediate
                ALUOp    = 2'b00;  // ADD for address calculation
                Rs1Valid = 1'b1;
            end
            STORE: begin
                MemWrite = 1'b1;
                ALUSrc   = 1'b1;
                ImmSel   = 3'b001; // S-type immediate
                ALUOp    = 2'b00;  // ADD for address calculation
                Rs1Valid = 1'b1;
                Rs2Valid = 1'b1;
            end
            BRANCH: begin
                Branch   = 1'b1;
                ImmSel   = 3'b010; // B-type immediate
                ALUOp    = 2'b01;  // SUB
                Rs1Valid = 1'b1;
                Rs2Valid = 1'b1;
            end
            JAL: begin
                Jump     = 1'b1;
                RegWrite = 1'b1;
                ImmSel   = 3'b011; // J-type immediate
            end
            JALR: begin
                Jump     = 1'b1;
                JALR_flag = 1'b1;
                RegWrite = 1'b1;
                ImmSel   = 3'b000; // I-type immediate
                ALUOp    = 2'b00;  // ADD for address calculation
                Rs1Valid = 1'b1;
            end
            LUI: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                ALUSrcA  = 2'b10;  // 0
                ImmSel   = 3'b100; // U-type immediate
                ALUOp    = 2'b00;  // ADD (0 + imm)
            end
            AUIPC: begin
                RegWrite = 1'b1;
                ALUSrc   = 1'b1;
                ALUSrcA  = 2'b01;  // PC
                ImmSel   = 3'b100; // U-type immediate
                ALUOp    = 2'b00;  // ADD (PC + imm)
            end
            SYSTEM: begin
                // ECALL/EBREAK: treated as NOP on bare-metal (no OS to handle syscalls).
                // All control signals remain at default (0). PC advances normally.
            end
            FENCE: begin
                // NOP: FENCE is a memory-ordering hint.
                // It has no effect on a single-cycle CPU with no caches
                // or out-of-order execution. All control signals stay 0.
            end
            default: begin
                IllegalInst = 1'b1;
            end
        endcase
    end

endmodule
