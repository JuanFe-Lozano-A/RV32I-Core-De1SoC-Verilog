# RV32I Core Subsystem (`rtl/core/`)

This directory contains the central brain and state-holding elements of the RISC-V processor. It is responsible for instruction fetching, decoding, register management, and orchestrating the entire datapath.

## Files & Responsibilities

### `rv32i_core.v`
This is the **Core Wrapper Module**. It acts as the "motherboard" for the CPU's internal architecture. 
- **What it does:** It does not contain raw behavioral logic; instead, it instantiates and physically wires together the `pc`, `register_file`, `control_unit`, and all modules from `rtl/datapath/` (ALU, Branch Unit, Imm Gen).
- **Connections:** It exports the memory interfaces (`instr_addr`, `data_addr`, `read_data`, `write_data`) up to the top-level FPGA wrappers, ensuring the CPU core is completely decoupled from the physical FPGA pins.

### `pc.v` (Program Counter)
The Program Counter is the **only clocked element in the CPU datapath**.
- **What it does:** It holds the 32-bit memory address of the current instruction. On the rising edge of the execution clock (`clk`), it updates its value.
- **Connections:** It receives its next value (`next_pc`) from the `branch_unit.v` (which decides if we increment by 4 or jump). It also interfaces directly with the `history_buffer.v` during a rollback to forcefully restore an old PC.

### `register_file.v`
The 32x32-bit General Purpose Register array.
- **What it does:** Holds variables `x0` through `x31`. It features two asynchronous read ports (combinational) and one synchronous write port. `x0` is hardwired to `0`.
- **Connections:** It receives addresses (`rs1`, `rs2`, `rd`) from the instruction decoder. It outputs data to the `alu.v` and receives results back. Like the PC, it exposes its entire internal 1024-bit state (`state_out`) to the `history_buffer.v` for rollback snapshots.

### `control_unit.v`
The central decoder and traffic cop.
- **What it does:** It takes the 32-bit instruction word from `instruction_memory.v` and combinatorially slices it into opcodes (`inst[6:0]`), `funct3`, and `funct7`. Based on these bits, it generates all the control signals (`reg_write`, `alu_src`, `mem_write`, `branch_type`, etc.) that tell the datapath what to do.
- **Connections:** Feeds massive amounts of control wires into `alu_control.v`, `register_file.v`, and the top-level memory bridges. It also generates the `illegal_inst` exception flag if it sees an unknown opcode.

## Multi-Architecture Compatibility

The `rv32i_core.v` is designed to be **memory-architecture agnostic**. It provides separate ports for instruction fetching and data access. 
- In **Harvard Mode**, these ports are connected to two physical memories.
- In **Von Neumann Mode**, these ports are connected to a single Dual-Port RAM.
The core logic does not change between modes, ensuring consistent instruction execution regardless of the memory layout.
