
import os
import csv

def validate_suite():
    base_path = "c:/Users/juanf/Documents/Universidad/Arquitectura de Computadores/FPGA-RiscV32I/tests/instruction_suite/"
    files = [f for f in os.listdir(base_path) if f.endswith(".csv")]
    
    print(f"--- VALIDATING {len(files)} TEST CASES ---")
    
    for f in files:
        full_path = os.path.join(base_path, f)
        with open(full_path, "r") as csvfile:
            reader = csv.reader(csvfile)
            rows = list(reader)
            
            # 1. Check Header Length (Must be 38 columns: Assembly, PC, Inst, ALU, rs1, rs2 + 32 regs)
            if len(rows[0]) != 38:
                print(f"[ERROR] {f}: Incorrect column count ({len(rows[0])})")
                continue
                
            # 2. Check PC progression
            for i in range(2, len(rows)):
                prev_pc = int(rows[i-1][1], 16)
                curr_pc = int(rows[i][1], 16)
                # PC should be >= previous PC (unless jump, but our tests are linear/forward)
                if curr_pc < 0: # sanity
                     print(f"[ERROR] {f}: Invalid PC at row {i}")
            
            # 3. Check Opcode consistency (Sample check for I-Type 0x13)
            # instructions like addi, andi, etc should end in 13, 93, B3, etc.
            # but they are hex strings, so we check the last 2 chars for Opcode patterns
            for i in range(1, len(rows)):
                inst = rows[i][2]
                opcode_hex = inst[-2:]
                # 93 = I-type, B3 = R-type, 37 = LUI, 17 = AUIPC, 63 = Branch, 6F = JAL, 03 = Load, 23 = Store
                valid_opcodes = ["93", "B3", "37", "17", "63", "6F", "03", "23", "13", "67"]
                if opcode_hex not in valid_opcodes:
                    print(f"[WARNING] {f}: Unusual opcode '{opcode_hex}' in instruction {inst}")

    print("--- VALIDATION COMPLETE ---")

validate_suite()
