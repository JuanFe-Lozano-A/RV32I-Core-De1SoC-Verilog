
import csv
import os

def to_hex(val, bits=32):
    return format(val & ((1 << bits) - 1), f'0{bits//4}x').upper()

def generate_test(name, instructions, initial_regs=None):
    base_path = "c:/Users/juanf/Documents/Universidad/Arquitectura de Computadores/FPGA-RiscV32I/tests/instruction_suite/"
    hex_path = f"{base_path}{name}.hex"
    csv_path = f"{base_path}{name}.csv"
    
    header = ["Assembly", "PC", "Inst", "ALU_Res", "rs1_val", "rs2_val"] + [f"x{i}" for i in range(32)]
    
    regs = [0] * 32
    if initial_regs:
        for r, v in initial_regs.items(): regs[r] = v
        
    csv_rows = []
    hex_lines = []
    
    pc = 0
    for asm, inst_hex, alu_res, r1_idx, r2_idx, rd_idx, new_val in instructions:
        r1_val = regs[r1_idx] if (r1_idx is not None and r1_idx < 32) else 0
        r2_val = regs[r2_idx] if (r2_idx is not None and r2_idx < 32) else 0
        
        if rd_idx is not None and rd_idx != 0:
            regs[rd_idx] = new_val
            
        row = [asm, to_hex(pc), inst_hex, to_hex(alu_res), to_hex(r1_val), to_hex(r2_val)] + [to_hex(r) for r in regs]
        csv_rows.append(row)
        hex_lines.append(inst_hex)
        pc += 4
        
    hex_lines.append("0000006F") # jal x0, 0
    
    with open(hex_path, "w") as f:
        f.write("\n".join(hex_lines))
    
    with open(csv_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(csv_rows)

# --- SUITE GENERATION ---

tests = {
    "addi": [
        ["li x1, 5", "00500093", 5, None, None, 1, 5],
        ["addi x2, x1, 10", "00A08113", 15, 1, None, 2, 15]
    ],
    "andi": [
        ["li x1, 0xFF", "0FF00093", 255, None, None, 1, 255],
        ["andi x2, x1, 0x0F", "00F0F113", 15, 1, None, 2, 15]
    ],
    "ori": [
        ["li x1, 0xF0", "0F000093", 240, None, None, 1, 240],
        ["ori x2, x1, 0x0F", "00F0E113", 255, 1, None, 2, 255]
    ],
    "xori": [
        ["li x1, 0xAA", "0AA00093", 170, None, None, 1, 170],
        ["xori x2, x1, 0xFF", "0FF0C113", 85, 1, None, 2, 85]
    ],
    "slli": [
        ["li x1, 1", "00100093", 1, None, None, 1, 1],
        ["slli x2, x1, 4", "00409113", 16, 1, None, 2, 16]
    ],
    "add": [
        ["li x1, 100", "06400093", 100, None, None, 1, 100],
        ["li x2, 200", "0C800113", 200, None, None, 2, 200],
        ["add x3, x1, x2", "002081B3", 300, 1, 2, 3, 300]
    ],
    "sub": [
        ["li x1, 500", "1F400093", 500, None, None, 1, 500],
        ["li x2, 100", "06400113", 100, None, None, 2, 100],
        ["sub x3, x1, x2", "402081B3", 400, 1, 2, 3, 400]
    ],
    "lui": [
        ["lui x10, 0x12345", "12345537", 0x12345000, None, None, 10, 0x12345000]
    ],
    "auipc": [
        ["auipc x10, 1", "00001517", 0x1000, None, None, 10, 0x1000]
    ],
    "load_store": [
        ["li x5, 0x80", "08000293", 0x80, None, None, 5, 0x80],
        ["li x10, 0xDEADBEEF", "DEADB537", 0xDEADB000, None, None, 10, 0xDEADB000], # lui
        ["addi x10, x10, 0x6EF", "6EF50513", 0xDEADBEEF, 10, None, 10, 0xDEADBEEF], # addi
        ["sw x10, 0(x5)", "00A2A023", 0x80, 5, 10, None, 0],
        ["lw x11, 0(x5)", "0002A583", 0x80, 5, None, 11, 0xDEADBEEF],
        ["lh x12, 0(x5)", "00029603", 0x80, 5, None, 12, 0xFFFFBEEF] # sign extended
    ],
    "branch_beq": [
        ["li x1, 10", "00A00093", 10, None, None, 1, 10],
        ["li x2, 10", "00A00113", 10, None, None, 2, 10],
        ["beq x1, x2, 8", "00208463", 10, 1, 2, None, 0], # Should jump to PC+8
        ["addi x3, x0, 1", "00100193", 1, 0, None, 3, 1], # Skipped
        ["addi x4, x0, 1", "00100213", 1, 0, None, 4, 1]  # Targeted
    ],
    "jal_test": [
        ["jal x1, 8", "008000EF", 4, None, None, 1, 4], # jump to PC+8, save PC+4 in x1
        ["addi x2, x0, 1", "00100113", 1, 0, None, 2, 1], # Skipped
        ["addi x3, x0, 2", "00200193", 2, 0, None, 3, 2]  # Targeted
    ]
}

for name, insts in tests.items():
    generate_test(name, insts)
    print(f"Generated {name}")
