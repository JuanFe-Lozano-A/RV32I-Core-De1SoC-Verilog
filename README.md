# RV32I Single-Core FPGA Processor — DE1-SoC

A fully-functional, single-cycle **RV32I RISC-V** processor implemented in Verilog and deployed on the **Terasic DE1-SoC** (Intel Cyclone V). Supports manual instruction stepping, full temporal rollback (step-backward), and a real-time hardware monitor via switches and 7-segment displays.

---

## Features

- **Full RV32I ISA**: R, I, S, B, U, J instruction types
- **Manual Execution Control**: Step forward / backward one instruction at a time using push-buttons
- **True State Rollback**: Stepping backward restores PC, all 32 registers, and data memory to their exact pre-step values (64 levels deep)
- **Real-Time Register Viewer**: Inspect any of the 32 CPU registers live using switches
- **32-bit Value Inspector**: Toggle between lower 24 bits and upper 8 bits of any displayed value
- **Exception Handling**: Detects illegal instructions and misaligned memory accesses; displays error code on HEX displays
- **Hardware Debug Monitor**: Switch-selectable view of PC, instruction, ALU result, rs1, rs2, or any register

---

## Hardware Interface

### Push-Buttons (KEY, Active Low)

| Button | Function |
|--------|----------|
| `KEY[0]` | **Master Reset** — resets PC, registers, and memory |
| `KEY[1]` | **Step Forward** — execute one instruction |
| `KEY[2]` | **Step Backward** — undo one instruction (restores PC + registers + memory) |

### Switches (SW)

| Switch(es) | Function |
|------------|----------|
| `SW[2:0]` | **Display mode** (see table below) |
| `SW[3]`   | **Upper byte modifier** — shows bits [31:24] on HEX1:HEX0, blanks HEX5:HEX2 |
| `SW[4]`   | **VGA Pip-Boy Screen Enable** — Up = ON (retro green), Down = Blank |
| `SW[9:5]` | **Register select** — selects x0–x31 when `SW[2:0] = 101` |

#### SW[2:0] Display Modes

| SW[2:0] | Display | Shows |
|---------|---------|-------|
| `000` | PC | Program Counter (byte address) |
| `001` | Instruction | 32-bit instruction word at current PC |
| `010` | Result | ALU / write-back result |
| `011` | rs1 | Source register 1 value |
| `100` | rs2 | Source register 2 value |
| `101` | Register | Value of the register selected by `SW[9:5]` |

> **Note:** In all modes, HEX5:HEX0 show bits **[23:0]** of the value by default (6 hex digits). Set `SW[3]=1` to see bits **[31:24]** on HEX1:HEX0 instead, with HEX5:HEX2 blanked.

#### Upper Byte Mode (SW[3])

| SW[3] | HEX5 | HEX4 | HEX3 | HEX2 | HEX1 | HEX0 |
|-------|------|------|------|------|------|------|
| `0` | bits[23:20] | bits[19:16] | bits[15:12] | bits[11:8] | bits[7:4] | bits[3:0] |
| `1` | OFF  | OFF  | OFF  | OFF  | bits[31:28] | bits[27:24] |

### LEDs (LEDR)

| LED | Condition |
|-----|-----------|
| `LEDR[0]` | ON when PC = 0 (start of program) |
| `LEDR[1]` | ON when CPU is in the infinite-loop exit state |
| `LEDR[9]` | ON when a trap/exception is active |
| `LEDR[8:2]` | Unused |

### Error Display (Trap Mode)

When a trap is active, HEX displays override all switches and show:

```
HEX5  HEX4  HEX3  HEX2  HEX1  HEX0
  E     0     0     0     0    cause
```

| `cause` | Meaning |
|---------|---------|
| `2` | Illegal Instruction |
| `4` | Misaligned Load |
| `6` | Misaligned Store |

> ECALL, EBREAK, and FENCE are treated as NOPs on this bare-metal system (no OS).

---

## Project Structure

```
FPGA-RiscV32I/
├── rtl/
│   ├── SingleCore_FPGA_RV32I.v       # Base Top-level: HEX & LEDs only
│   ├── SingleCore_FPGA_RV32I_VGA.v   # VGA Top-level: includes VGA subsystem
│   ├── core/
│   │   ├── rv32i_core.v          # CPU datapath, FSM, CSRs, history buffer control
│   │   ├── control_unit.v        # Instruction decoder, control signal generator
│   │   ├── register_file.v       # 32×32-bit sync register file
│   │   └── pc.v                  # Program Counter
│   ├── datapath/
│   │   ├── alu.v                 # 32-bit ALU
│   │   ├── alu_control.v         # ALU operation selector
│   │   ├── branch_unit.v         # Branch condition evaluator
│   │   └── imm_gen.v             # Immediate value generator
│   ├── memory/
│   │   ├── instruction_memory.v  # 64×32-bit ROM ($readmemh from program.hex)
│   │   ├── data_memory.v         # 32×32-bit sync RAM (4 byte-lane banks)
│   │   ├── history_buffer.v      # 64-entry × 2080-bit dual BRAM stack for rollback
│   │   └── address_bridge.v      # Memory-mapped I/O router
│   ├── io/
│   │   └── hex_decoder.v         # 4-bit → 7-segment decoder (active low)
│   └── vga/
│       ├── vga_controller.v      # Standard 640x480 @ 60Hz timing generator
│       ├── font_rom.v            # 8x16 ASCII Font ROM
│       └── text_engine.v         # Renders CPU state to 80x30 character grid
├── tb/
│   ├── integration_test_tb.v     # Full system integration testbench
│   ├── verify_tests_tb.v         # Verification bench for HEX test programs
│   ├── verify_mem_tb.v           # Verification bench for Data Memory
│   └── verify_vga_tb.v           # Verification bench for VGA timing
├── tests/
│   └── code_tests/               # Assembly hex programs and matching reference CSVs
├── FPGA-RiscV32I.qsf             # Base Quartus Revision (No VGA)
├── FPGA-RiscV32I_VGA.qsf         # VGA Quartus Revision (Includes VGA pins)
├── program.hex                   # Active RV32I machine code (loaded at synthesis)
└── README.md
```

---

## Memory Map

| Address Range | Region | Notes |
|---------------|--------|-------|
| `0x0000–0x00FC` | Instruction ROM | 64 words, loaded from `program.hex` |
| `0x0000–0x007C` | Data RAM | 32 words (128 bytes), four 8-bit byte banks |
| `0x2000–0x3FFF` | I/O Space | Reserved for future peripherals |

---

## Architecture Notes

### Single-Cycle, Fully Async Datapath
The only clocked element in the CPU datapath is the **Program Counter**. The register file and data memory use asynchronous latches, enabling the manual-step workflow without clock gating.

### Memory Rollback
The history buffer saves a 2080-bit snapshot on every forward step:
```
Snapshot = [ PC (32) | Registers x0–x31 (1024) | Data Memory (1024) ]
```
Stepping backward pops the snapshot and simultaneously restores all three components. Memory writes (SW/SH/SB) are fully undoable.

### Four-Bank Byte-Lane Memory
Data memory uses four independent 8-bit arrays (one per byte lane) rather than a single 32-bit array. This matches how physical SRAM with byte-enables works and simplifies sub-word access logic for `LB`, `LH`, `LW`.

---

## Synthesis (Quartus Prime) & Compilation

This project uses **Quartus Revisions** to allow you to easily opt in or out of the VGA screen feature without messing up your pin assignments.

### To Run WITHOUT VGA (Base Mode)
1. Open the project in Quartus Prime (`FPGA-RiscV32I.qpf`).
2. Go to **Project > Revisions...**
3. Select `FPGA-RiscV32I` and click **Set Current**.
4. Double-click **Compile Design**.
5. Program the DE1-SoC. The FPGA will only use the HEX displays and LEDs.

### To Run WITH VGA (Pip-Boy Monitor Mode)
1. Open the project in Quartus Prime (`FPGA-RiscV32I.qpf`).
2. Go to **Project > Revisions...**
3. Select `FPGA-RiscV32I_VGA` and click **Set Current**.
4. Double-click **Compile Design**.
5. Program the DE1-SoC.
6. Connect a VGA monitor to the board. 
7. Flip **`SW[4]` to the UP position** to turn on the screen!

> **Note:** To change the program the CPU runs, copy one of the `.hex` files from `tests/code_tests/` into the root directory, rename it to `program.hex`, and recompile your chosen revision.

---

## Running Simulation

```powershell
# Compile
iverilog -s integration_test_tb -o tb/integration_sim `
  tb/integration_test_tb.v rtl/SingleCore_FPGA_RV32I.v `
  rtl/core/rv32i_core.v rtl/core/control_unit.v rtl/core/pc.v `
  rtl/core/register_file.v rtl/datapath/alu.v rtl/datapath/alu_control.v `
  rtl/datapath/branch_unit.v rtl/datapath/imm_gen.v `
  rtl/memory/instruction_memory.v rtl/memory/data_memory.v `
  rtl/memory/address_bridge.v rtl/memory/history_buffer.v `
  rtl/io/hex_decoder.v

# Run
vvp tb/integration_sim
```

Expected output: 5 PASS results with no errors.

---

## The VGA Pip-Boy Monitor

The `dev` branch includes a complete **640x480 @ 60Hz VGA Monitor** that visualizes the internal state of the RV32I core without interfering with its logic. 

The screen shows:
- The current PC and Instruction
- A full grid of all 32 registers (`x0`-`x31`)
- The ALU Result
- Status flags (`FIRST INST`, `HALTED`, `TRAP E0000x`)
