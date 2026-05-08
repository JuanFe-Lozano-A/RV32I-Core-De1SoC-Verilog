# RV32I Memory Subsystem (`rtl/memory/`)

This directory manages all state storage, memory-mapped routing, and the core hardware rollback (undo) mechanism that makes this FPGA implementation unique.

## Files & Responsibilities

### `instruction_memory.v`
The Read-Only Memory (ROM) that holds the active program.
- **What it does:** It is a 64-word array (256 bytes) that is initialized at synthesis time using `$readmemh("program.hex")`. It acts purely combinationally: given an address, it instantly outputs the 32-bit instruction at that address.
- **Connections:** Receives the address from `pc.v` and outputs the instruction directly to the `control_unit.v` and `imm_gen.v`.

### `data_memory.v`
The Random Access Memory (RAM) for program data.
- **What it does:** It is a 32-word array (128 bytes) constructed using four independent 8-bit "byte lanes." This allows the CPU to execute sub-word operations (`LB`, `SB`, `LH`, `SH`) easily by toggling specific byte-enable wires rather than doing complex read-modify-write cycles. It features a synchronous write port and an asynchronous read port to allow single-cycle operation.
- **Connections:** Receives memory read/write requests from the `address_bridge.v`. It exposes its entire 1024-bit internal state to the `history_buffer.v` every clock cycle for backup, and features a `restore_en` port to allow the history buffer to completely overwrite it during a rollback.

### `history_buffer.v`
The Hardware Undo Engine.
- **What it does:** This is a dual-BRAM stack that takes a massive, single-cycle snapshot of the entire CPU (The PC, all 32 Registers, and all 128 bytes of Data Memory) every time a forward step is executed. If a backward step is requested, it pops the stack and simultaneously forces the PC, Register File, and Data Memory back to their previous states.
- **Connections:** Interfaces with the massive 1024-bit `state_out` and `restore_data` buses of both the `register_file.v` and `data_memory.v`.

### `address_bridge.v`
The Memory-Mapped I/O Router.
- **What it does:** Because the FPGA has limited RAM, we map physical addresses to different locations. If the CPU tries to write to address `0x00`, it goes to RAM. If it tries to write to address `0x2000`, the bridge reroutes the data to an external output (like LED displays). It intercepts all memory requests from the core and routes them to the correct hardware.
- **Connections:** Sits directly between the `rv32i_core.v` output ports and the physical `data_memory.v` or external FPGA I/O pins.
