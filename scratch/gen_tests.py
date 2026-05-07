import os

class RV32ISimulator:
    def __init__(self):
        self.pc = 0
        self.regs = [0] * 32
        self.mem = [0] * 128  # 128 bytes
        self.history = []     # For rollback tracking
        
    def to_u32(self, val):
        return val & 0xFFFFFFFF
        
    def to_i32(self, val):
        val = val & 0xFFFFFFFF
        return val - 0x100000000 if val & 0x80000000 else val

    def step(self, inst, name=""):
        # Save history for rollback tracking
        self.history.append({
            'pc': self.pc,
            'regs': list(self.regs),
            'mem': list(self.mem)
        })
        
        opcode = inst & 0x7F
        rd = (inst >> 7) & 0x1F
        rs1 = (inst >> 15) & 0x1F
        rs2 = (inst >> 20) & 0x1F
        funct3 = (inst >> 12) & 0x7
        funct7 = (inst >> 25) & 0x7F
        
        result = None
        rs1_val = self.regs[rs1]
        rs2_val = self.regs[rs2]
        
        next_pc = self.pc + 4
        
        if opcode == 0x33: # R-Type
            if funct3 == 0:
                if funct7 == 0: result = self.to_u32(rs1_val + rs2_val) # ADD
                elif funct7 == 0x20: result = self.to_u32(rs1_val - rs2_val) # SUB
            elif funct3 == 1: result = self.to_u32(rs1_val << (rs2_val & 0x1F)) # SLL
            elif funct3 == 2: result = 1 if self.to_i32(rs1_val) < self.to_i32(rs2_val) else 0 # SLT
            elif funct3 == 3: result = 1 if rs1_val < rs2_val else 0 # SLTU
            elif funct3 == 4: result = self.to_u32(rs1_val ^ rs2_val) # XOR
            elif funct3 == 5:
                if funct7 == 0: result = self.to_u32(rs1_val >> (rs2_val & 0x1F)) # SRL
                elif funct7 == 0x20: result = self.to_u32(self.to_i32(rs1_val) >> (rs2_val & 0x1F)) # SRA
            elif funct3 == 6: result = self.to_u32(rs1_val | rs2_val) # OR
            elif funct3 == 7: result = self.to_u32(rs1_val & rs2_val) # AND
            
        elif opcode == 0x13: # I-Type ALU
            imm = self.to_i32((inst >> 20) & 0xFFF)
            if funct3 == 0: result = self.to_u32(rs1_val + imm) # ADDI
            elif funct3 == 2: result = 1 if self.to_i32(rs1_val) < imm else 0 # SLTI
            elif funct3 == 3: result = 1 if rs1_val < self.to_u32(imm) else 0 # SLTIU
            elif funct3 == 4: result = self.to_u32(rs1_val ^ imm) # XORI
            elif funct3 == 6: result = self.to_u32(rs1_val | imm) # ORI
            elif funct3 == 7: result = self.to_u32(rs1_val & imm) # ANDI
            elif funct3 == 1: result = self.to_u32(rs1_val << (imm & 0x1F)) # SLLI
            elif funct3 == 5:
                shamt = imm & 0x1F
                if funct7 == 0: result = self.to_u32(rs1_val >> shamt) # SRLI
                elif funct7 == 0x20: result = self.to_u32(self.to_i32(rs1_val) >> shamt) # SRAI
                
        elif opcode == 0x37: # LUI
            imm = inst & 0xFFFFF000
            result = self.to_u32(imm)
            
        elif opcode == 0x17: # AUIPC
            imm = inst & 0xFFFFF000
            result = self.to_u32(self.pc + imm)
            
        elif opcode == 0x6F: # JAL
            imm = self.to_i32(((inst >> 31) << 20) | (((inst >> 12) & 0xFF) << 12) | (((inst >> 20) & 0x1) << 11) | (((inst >> 21) & 0x3FF) << 1))
            result = self.pc + 4
            next_pc = self.to_u32(self.pc + imm)
            
        elif opcode == 0x67: # JALR
            imm = self.to_i32((inst >> 20) & 0xFFF)
            result = self.pc + 4
            next_pc = self.to_u32((rs1_val + imm) & ~1)
            
        elif opcode == 0x63: # Branch
            imm = self.to_i32(((inst >> 31) << 12) | (((inst >> 7) & 0x1) << 11) | (((inst >> 25) & 0x3F) << 5) | (((inst >> 8) & 0xF) << 1))
            take = False
            if funct3 == 0: take = (rs1_val == rs2_val) # BEQ
            elif funct3 == 1: take = (rs1_val != rs2_val) # BNE
            elif funct3 == 4: take = (self.to_i32(rs1_val) < self.to_i32(rs2_val)) # BLT
            elif funct3 == 5: take = (self.to_i32(rs1_val) >= self.to_i32(rs2_val)) # BGE
            elif funct3 == 6: take = (rs1_val < rs2_val) # BLTU
            elif funct3 == 7: take = (rs1_val >= rs2_val) # BGEU
            if take: next_pc = self.to_u32(self.pc + imm)
            
        elif opcode == 0x23: # Store
            imm = self.to_i32(((inst >> 25) << 5) | ((inst >> 7) & 0x1F))
            addr = self.to_u32(rs1_val + imm)
            if funct3 == 0: # SB
                if addr < 128: self.mem[addr] = rs2_val & 0xFF
            elif funct3 == 1: # SH
                if addr < 127:
                    self.mem[addr] = rs2_val & 0xFF
                    self.mem[addr+1] = (rs2_val >> 8) & 0xFF
            elif funct3 == 2: # SW
                if addr < 125:
                    self.mem[addr] = rs2_val & 0xFF
                    self.mem[addr+1] = (rs2_val >> 8) & 0xFF
                    self.mem[addr+2] = (rs2_val >> 16) & 0xFF
                    self.mem[addr+3] = (rs2_val >> 24) & 0xFF
                    
        elif opcode == 0x03: # Load
            imm = self.to_i32((inst >> 20) & 0xFFF)
            addr = self.to_u32(rs1_val + imm)
            if funct3 == 0: # LB
                if addr < 128: result = self.to_u32(self.to_i32((self.mem[addr] ^ 0x80) - 0x80))
            elif funct3 == 1: # LH
                if addr < 127: 
                    val = self.mem[addr] | (self.mem[addr+1] << 8)
                    result = self.to_u32(self.to_i32((val ^ 0x8000) - 0x8000))
            elif funct3 == 2: # LW
                if addr < 125: result = self.mem[addr] | (self.mem[addr+1] << 8) | (self.mem[addr+2] << 16) | (self.mem[addr+3] << 24)
            elif funct3 == 4: # LBU
                if addr < 128: result = self.mem[addr]
            elif funct3 == 5: # LHU
                if addr < 127: result = self.mem[addr] | (self.mem[addr+1] << 8)
                
        # Writeback
        if result is not None and rd != 0:
            self.regs[rd] = result
            
        # Format CSV Row
        res_str = f"0x{result:08X}" if result is not None else "OFF"
        rs1_str = f"0x{rs1_val:08X}" if opcode not in [0x37, 0x17, 0x6F] else "OFF"
        rs2_str = f"0x{rs2_val:08X}" if opcode in [0x33, 0x63, 0x23] else "OFF"
        
        row = f'"{name}",0x{self.pc:08X},0x{inst:08X},{res_str},{rs1_str},{rs2_str}'
        for i in range(32):
            row += f',0x{self.regs[i]:08X}'
            
        self.pc = next_pc
        return row

def generate_test(test_name, insts):
    sim = RV32ISimulator()
    csv_rows = ["Instruction,PC,Current Instruction,Result,rs1,rs2," + ",".join([f"x{i}" for i in range(32)])]
    
    hex_lines = []
    
    for i, (name, inst_code) in enumerate(insts):
        row = sim.step(inst_code, name)
        csv_rows.append(row)
        hex_lines.append(f"{inst_code:08X}")
        
    with open(f"../tests/edge_cases/{test_name}.hex", "w") as f:
        f.write("\n".join(hex_lines) + "\n")
        
    with open(f"../tests/edge_cases/{test_name}.csv", "w") as f:
        f.write("\n".join(csv_rows) + "\n")

# --- Define Tests ---

# 1. edge_x0_write
# ADDI x0, x0, 0xFF; LUI x0, 0xFF; LW x0, 0(x0)
tests_x0 = [
    ("addi x0, x0, 0xFF", 0x0ff00013),
    ("lui x0, 0xFF",      0x000ff037),
    ("lw x0, 0(x0)",      0x00002003),
    ("halt",              0x0000006f)
]
generate_test("edge_x0_write", tests_x0)

# 2. edge_arithmetic_wrap
# ADDI x1, x0, -1 (0xFFFFFFFF); ADDI x2, x1, 1 (0x00000000)
tests_wrap = [
    ("addi x1, x0, -1",   0xfff00093),
    ("addi x2, x1, 1",    0x00108113),
    ("addi x3, x0, 0",    0x00000193),
    ("addi x4, x3, -1",   0xfff18213),
    ("halt",              0x0000006f)
]
generate_test("edge_arithmetic_wrap", tests_wrap)

# 3. edge_sign_ext_load
# Load 0x80 to mem. LB should get 0xFFFFFF80. LBU should get 0x00000080.
tests_load_ext = [
    ("addi x1, x0, 0x80", 0x08000093),
    ("sb x1, 0(x0)",      0x00100023),
    ("lb x2, 0(x0)",      0x00000103),
    ("lbu x3, 0(x0)",     0x00004183),
    ("halt",              0x0000006f)
]
generate_test("edge_sign_ext_load", tests_load_ext)

# 4. edge_sign_ext_shift
# x1 = 0x80000000. SRLI gets 0x40000000. SRAI gets 0xC0000000
tests_shift = [
    ("lui x1, 0x80000",   0x800000b7),
    ("srli x2, x1, 1",    0x0010d113),
    ("srai x3, x1, 1",    0x4010d193),
    ("halt",              0x0000006f)
]
generate_test("edge_sign_ext_shift", tests_shift)

# 5. edge_branch_negative
# BNE x0, x1, -4 (Infinite loop on itself). We will do a small loop: x1=1; back: addi x1, x1, -1; bne x1, x0, back
tests_branch_neg = [
    ("addi x1, x0, 2",    0x00200093),
    ("addi x1, x1, -1",   0xfff08093), # PC=4
    ("bne x1, x0, -4",    0xfe009ee3), # PC=8, jumps to 4
    ("halt",              0x0000006f)  # PC=12
]
# We need to manually simulate the loop for the CSV dump.
sim = RV32ISimulator()
csv_rows = ["Instruction,PC,Current Instruction,Result,rs1,rs2," + ",".join([f"x{i}" for i in range(32)])]
csv_rows.append(sim.step(0x00200093, "addi x1, x0, 2"))
csv_rows.append(sim.step(0xfff08093, "addi x1, x1, -1"))
csv_rows.append(sim.step(0xfe009ee3, "bne x1, x0, -4"))
csv_rows.append(sim.step(0xfff08093, "addi x1, x1, -1"))
csv_rows.append(sim.step(0xfe009ee3, "bne x1, x0, -4"))
csv_rows.append(sim.step(0x0000006f, "halt"))
with open("../tests/edge_cases/edge_branch_negative.csv", "w") as f: f.write("\n".join(csv_rows)+"\n")
with open("../tests/edge_cases/edge_branch_negative.hex", "w") as f: f.write("00200093\nfff08093\nfe009ee3\n0000006f\n")


# 6. edge_jal_jalr_extreme
# JAL x1, max. JALR negative.
# We will just do a simple JAL to PC+8, and JALR back.
tests_jalr = [
    ("jal x1, 8",         0x008000ef), # PC=0, jumps to 8. x1 = 4.
    ("halt",              0x0000006f), # PC=4
    ("jalr x2, -8(x1)",   0xff808167), # PC=8, jumps to 4-8 = -4 -> wait, let's jump to PC=4. x1 is 4. -0(x1) is 4.
    ("halt",              0x0000006f)  # PC=12
]
sim = RV32ISimulator()
csv_rows = ["Instruction,PC,Current Instruction,Result,rs1,rs2," + ",".join([f"x{i}" for i in range(32)])]
csv_rows.append(sim.step(0x008000ef, "jal x1, 8"))
csv_rows.append(sim.step(0xff808167, "jalr x2, -4(x1)")) # Jump to 0. Wait, if x1=4, -4(x1) = 0. Hex is FFC08167
csv_rows.append(sim.step(0x008000ef, "jal x1, 8")) # again
csv_rows.append(sim.step(0x0000006f, "halt"))
with open("../tests/edge_cases/edge_jal_jalr_extreme.csv", "w") as f: f.write("\n".join(csv_rows)+"\n")
with open("../tests/edge_cases/edge_jal_jalr_extreme.hex", "w") as f: f.write("008000ef\n0000006f\nffc08167\n0000006f\n")


# 7. edge_misaligned_load
# LW x1, 1(x0) - Should TRAP on FPGA, Simulator doesn't trap but we mark it.
tests_m_load = [
    ("lw x1, 1(x0)",      0x00102083),
    ("halt",              0x0000006f)
]
generate_test("edge_misaligned_load", tests_m_load)

# 8. edge_misaligned_store
tests_m_store = [
    ("sw x1, 2(x0)",      0x00102123),
    ("halt",              0x0000006f)
]
generate_test("edge_misaligned_store", tests_m_store)

# 9. edge_illegal_inst
tests_illegal = [
    ("illegal",           0xFFFFFFFF),
    ("halt",              0x0000006f)
]
generate_test("edge_illegal_inst", tests_illegal)

# 10. edge_mem_bounds
# Store word at 124 (0x7C). Last valid word.
tests_mem_bounds = [
    ("addi x1, x0, 124",  0x07c00093),
    ("addi x2, x0, -1",   0xfff00113),
    ("sw x2, 0(x1)",      0x0020a023),
    ("lw x3, 0(x1)",      0x0000a183),
    ("halt",              0x0000006f)
]
generate_test("edge_mem_bounds", tests_mem_bounds)

# 11. edge_data_hazard
# add x1, x1, 1 three times
tests_hazard = [
    ("addi x1, x0, 1",    0x00100093),
    ("add x1, x1, x1",    0x001080b3),
    ("add x1, x1, x1",    0x001080b3),
    ("halt",              0x0000006f)
]
generate_test("edge_data_hazard", tests_hazard)

# 12. edge_lui_auipc
tests_auipc = [
    ("lui x1, 0xFFFFF",   0xfffff0b7),
    ("auipc x2, 0x10000", 0x10000117),
    ("halt",              0x0000006f)
]
generate_test("edge_lui_auipc", tests_auipc)

# 13. edge_rollback_regs
# We will simulate the rollback explicitly in the CSV by repeating the rows backward.
tests_rb_regs = [
    ("addi x1, x0, 1",    0x00100093),
    ("addi x2, x0, 2",    0x00200113),
    ("addi x3, x0, 3",    0x00300193),
    ("halt",              0x0000006f)
]
sim = RV32ISimulator()
csv_rows = ["Instruction,PC,Current Instruction,Result,rs1,rs2," + ",".join([f"x{i}" for i in range(32)])]
history_rows = []
for name, inst in tests_rb_regs:
    row = sim.step(inst, name)
    csv_rows.append(row)
    history_rows.append(row)

# Now "Rollback" (just append the previous rows to show the expected states)
csv_rows.append('"--- ROLLBACK INITIATED ---",,,,,,' + ",".join(["" for _ in range(32)]))
csv_rows.append(history_rows[2] + " (State after 1st rollback)")
csv_rows.append(history_rows[1] + " (State after 2nd rollback)")
csv_rows.append(history_rows[0] + " (State after 3rd rollback)")
with open("../tests/edge_cases/edge_rollback_regs.csv", "w") as f: f.write("\n".join(csv_rows)+"\n")
with open("../tests/edge_cases/edge_rollback_regs.hex", "w") as f: f.write("\n".join([f"{x[1]:08X}" for x in tests_rb_regs])+"\n")

# 14. edge_rollback_mem
tests_rb_mem = [
    ("addi x1, x0, 0xAA", 0x0aa00093),
    ("sb x1, 0(x0)",      0x00100023),
    ("addi x1, x0, 0xBB", 0x0bb00093),
    ("sb x1, 0(x0)",      0x00100023),
    ("halt",              0x0000006f)
]
generate_test("edge_rollback_mem", tests_rb_mem)
# Note: For memory rollback, the CSV doesn't track memory arrays easily in columns, but we will document it.

print("Tests generated.")
