# FPGA RISC-V 32I Single Core

Welcome to the **RV32I Base Integer FPGA Processor** project! This repository contains a fully compliant, educational 32-bit RISC-V processor designed to be synthesized onto a **Terasic DE1-SoC FPGA board** using Quartus Prime.

## 🚀 Quick Start Guide

### 1. Writing Your Program
This processor executes standard RISC-V machine code. You can compile any C or Assembly code targeting the `rv32i` architecture.
1. Compile your program (e.g., using `riscv32-unknown-elf-gcc`).
2. Extract the raw hexadecimal machine code.
3. Open the **`program.hex`** file in the root directory.
4. Paste your hex codes into `program.hex`. 
   - *Rule: One 32-bit instruction per line, pure hex (e.g. `00100093`), no `0x` prefixes.*

### 2. Flashing to the FPGA
Because the `instruction_memory` automatically reads `program.hex`, you do not need to edit any Verilog files to change the program!
1. Open **Quartus Prime Lite**.
2. Open the project file: **`FPGA-RiscV32I.qpf`**.
3. Double-click **Compile Design**.
4. Open the **Programmer**, select your DE1-SoC board, and burn the resulting `.sof` file.

---

## 🎛️ Physical Hardware Interface

Once the design is running on the DE1-SoC board, you can use the physical switches and buttons to control the execution and debug your code in real-time.

### Control Buttons (Keys)
*   **`KEY0`**: **Reset.** Press to reset the processor and return the Program Counter to `0`.
*   **`KEY1`**: **Step Forward.** Press to execute exactly **one** instruction.
*   **`KEY2`**: **Step Backward.** Press to undo the last instruction (uses the internal history buffer to rollback state).

### LED Indicators
*   **`LEDR[0]`**: **Start.** Lights up when the processor is at the very first instruction (`PC == 0`).
*   **`LEDR[1]`**: **Done.** Lights up when the processor executes the standard infinite-loop exit command (`JAL x0, 0` / `0000006F`).
*   **`LEDR[9]`**: **Crash / Trap.** Lights up if the CPU encounters an illegal instruction or a misaligned memory access.

### Hardware Monitor (HEX Displays & Switches)
You can view the internal state of the processor on the six 7-segment displays (`HEX5` down to `HEX0`) by flipping the first three switches (`SW[2:0]`):

| Switches `[2:0]` | Display Mode | Description |
| :--- | :--- | :--- |
| `0 0 0` | **Program Counter** | Shows the current memory address of the instruction being processed. |
| `0 0 1` | **Current Instruction** | Shows the raw 32-bit Hex code being read from `program.hex`. |
| `0 1 0` | **Result** | Shows the final computed result of the instruction (what is being saved to a register). |
| `0 1 1` | **Register 1 (rs1)** | Shows the value read from the first source register. |
| `1 0 0` | **Register 2 (rs2)** | Shows the value read from the second source register. |

> [!NOTE]
> **Dynamic Blanking:** If an instruction does not use `rs1`, `rs2`, or does not produce a register result (e.g., a `JUMP` instruction doesn't use `rs1`), the HEX displays will automatically go blank when you try to view that specific invalid field!

---

## 🏗️ Architecture Features
*   **Full RV32I Compliance:** Supports all 40 Base Integer instructions, including shifts, Set-Less-Than, Register Jumps, and Upper Immediates.
*   **Reverse Execution:** Features an experimental history buffer that saves register and PC states, allowing for physical reverse-stepping of code.
*   **Trap Handling:** Basic CSR support (`mepc`, `mcause`) catches illegal operations and redirects execution to a built-in trap handler.
