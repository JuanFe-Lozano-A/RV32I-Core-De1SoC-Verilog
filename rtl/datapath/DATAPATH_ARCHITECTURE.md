# RV32I Datapath Subsystem (`rtl/datapath/`)

This directory contains the computational "muscle" of the CPU. These modules perform the actual math, logic operations, bit-shifting, and address calculations required by the instructions.

## Files & Responsibilities

### `alu.v` (Arithmetic Logic Unit)
The workhorse of the processor.
- **What it does:** It takes two 32-bit inputs (`a` and `b`) and performs a mathematical or logical operation based on the 4-bit `alu_op` signal. It supports `ADD`, `SUB`, `SLL` (Shift Left Logical), `SLT` (Set Less Than), `SLTU`, `XOR`, `SRL` (Shift Right Logical), `SRA` (Shift Right Arithmetic), `OR`, and `AND`.
- **Connections:** Input `a` usually comes from `rs1`. Input `b` comes from a multiplexer choosing between `rs2` or the generated Immediate. The output (`alu_result`) is sent to the Data Memory (as an address), the Register File (for write-back), and the Branch Unit (for jump calculations).

### `alu_control.v`
The translator for the ALU.
- **What it does:** It takes the generic `alu_op_type` from the `control_unit` and combines it with the `funct3` and `funct7` bits from the instruction to determine exactly which specific operation the `alu.v` must perform. For example, it differentiates between an `ADD` and a `SUB` which share the same base opcode and `funct3` but differ in `funct7`.
- **Connections:** Sits directly between `control_unit.v` and `alu.v`.

### `imm_gen.v` (Immediate Generator)
The bit-manipulator for constants.
- **What it does:** RISC-V instructions have hardcoded constants (immediates) embedded inside the 32-bit instruction word, but they are scrambled across different bits depending on the instruction format (I, S, B, U, J). This module extracts those bits, reconstructs the 32-bit immediate, and properly sign-extends it.
- **Connections:** Reads the raw 32-bit instruction from memory. Outputs the reconstructed 32-bit immediate to the ALU and the Branch Unit.

### `branch_unit.v`
The PC jump calculator.
- **What it does:** Calculates the `next_pc`. By default, it outputs `PC + 4`. If a branch instruction is active, it evaluates the condition (e.g., is `rs1 == rs2`?) and, if true, calculates `PC + Immediate`. It also handles absolute jumps (`JAL`, `JALR`).
- **Connections:** Reads the current `PC`, the `rs1` and `rs2` values from the register file, and the Immediate from `imm_gen.v`. It feeds the final `next_pc` back to `pc.v`.
