import sys

def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_s(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0xFFF
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0 = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def encode_b(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0x1FFE
    imm12 = (imm >> 12) & 0x1
    imm11 = (imm >> 11) & 0x1
    imm10_5 = (imm >> 5) & 0x3F
    imm4_1 = (imm >> 1) & 0xF
    return (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_1 << 8) | (imm11 << 7) | opcode

def encode_u(imm, rd, opcode):
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode

def encode_j(imm, rd, opcode):
    imm = imm & 0x1FFFFE
    imm20 = (imm >> 20) & 0x1
    imm19_12 = (imm >> 12) & 0xFF
    imm11 = (imm >> 11) & 0x1
    imm10_1 = (imm >> 1) & 0x3FF
    return (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | (rd << 7) | opcode

OP_R = 0x33
OP_I = 0x13
OP_LOAD = 0x03
OP_STORE = 0x23
OP_B = 0x63
OP_JAL = 0x6F
OP_JALR = 0x67
OP_LUI = 0x37
OP_AUIPC = 0x17

instructions = [
    # --- Initialization ---
    encode_u(0x1000, 1, OP_LUI),           # 0: LUI x1, 0x1000
    encode_i(0x010, 1, 0, 1, OP_I),        # 4: ADDI x1, x1, 16 (x1 = 0x1000010)
    encode_i(0x123, 0, 0, 2, OP_I),        # 8: ADDI x2, x0, 0x123
    
    # --- Arithmetic/Logic (R-Type) ---
    encode_r(0x00, 2, 1, 0, 3, OP_R),      # 12: ADD x3, x1, x2
    encode_r(0x20, 2, 1, 0, 4, OP_R),      # 16: SUB x4, x1, x2
    encode_r(0x00, 2, 1, 7, 5, OP_R),      # 20: AND x5, x1, x2
    encode_r(0x00, 2, 1, 6, 6, OP_R),      # 24: OR x6, x1, x2
    encode_r(0x00, 2, 1, 4, 7, OP_R),      # 28: XOR x7, x1, x2
    
    # --- Shifts ---
    encode_i(0x04, 0, 0, 8, OP_I),         # 32: ADDI x8, x0, 4
    encode_r(0x00, 8, 2, 1, 9, OP_R),      # 36: SLL x9, x2, x8 (0x123 << 4)
    encode_r(0x00, 8, 2, 5, 10, OP_R),     # 40: SRL x10, x2, x8 (0x123 >> 4)
    encode_r(0x20, 8, 2, 5, 11, OP_R),     # 44: SRA x11, x2, x8 (0x123 >> 4, arithmetic)
    encode_i(0x04, 2, 1, 12, OP_I),        # 48: SLLI x12, x2, 4
    encode_i(0x04, 2, 5, 13, OP_I),        # 52: SRLI x13, x2, 4
    encode_i(0x404, 2, 5, 14, OP_I),       # 56: SRAI x14, x2, 4 (funct7=0x20 -> imm=0x400 | 4)
    
    # --- Set Less Than ---
    encode_r(0x00, 2, 1, 2, 15, OP_R),     # 60: SLT x15, x1, x2 (0x1000010 < 0x123 -> 0)
    encode_r(0x00, 2, 1, 3, 16, OP_R),     # 64: SLTU x16, x1, x2
    encode_i(0x124, 2, 2, 17, OP_I),       # 68: SLTI x17, x2, 0x124 (0x123 < 0x124 -> 1)
    encode_i(0x124, 2, 3, 18, OP_I),       # 72: SLTIU x18, x2, 0x124
    
    # --- Memory ---
    encode_u(0x0, 20, OP_LUI),             # 76: LUI x20, 0 (Base address = 0)
    encode_i(0x0, 20, 0, 20, OP_I),        # 80: ADDI x20, x20, 0 (Memory bounded at 1024 bytes)
    encode_s(0x0, 2, 20, 2, OP_STORE),     # 84: SW x2, 0(x20) (Store 0x123 at Mem[0])
    encode_s(0x4, 3, 20, 2, OP_STORE),     # 88: SW x3, 4(x20) (Store ADD result at Mem[4])
    encode_i(0x0, 20, 2, 21, OP_LOAD),     # 92: LW x21, 0(x20) (Load 0x123 into x21)
    
    # --- Jumps & Branches ---
    encode_b(8, 2, 21, 0, OP_B),           # 96: BEQ x21, x2, 8 (x21 == x2, branch to 96+8=104)
    encode_i(0x0, 0, 0, 0, OP_I),          # 100: NOP (Should be skipped)
    
    encode_u(0x1, 22, OP_AUIPC),           # 104: AUIPC x22, 1 (x22 = 104 + 0x1000 = 0x1068)
    encode_j(8, 23, OP_JAL),               # 108: JAL x23, 8 (x23 = 112, jump to 116)
    encode_i(0x0, 0, 0, 0, OP_I),          # 112: NOP (Should be skipped)
    
    encode_i(8, 23, 0, 24, OP_JALR),       # 116: JALR x24, x23, 8 (Jump to 112+8=120)
    
    encode_i(0x0, 0, 0, 0, OP_I),          # 120: NOP
    encode_j(0, 0, OP_JAL),                # 124: JAL x0, 0 (Infinite Loop)
]

with open('program.hex', 'w') as f:
    for instr in instructions:
        f.write(f"{instr:08x}\n")
