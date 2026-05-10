# FPGA RISC-V Verification Guide

This guide details the extensive suite of mathematical edge-case tests designed to verify the robust execution of the RV32I processor on the DE1-SoC.

All test `.csv` files in this directory are generated in a highly structured, machine-readable "wide" format. Every row represents exactly one clock cycle (one instruction) and includes the Program Counter, the decoded Instruction, the ALU Result, and the exact state of all 32 registers (`x0` through `x31`). This format is ideal for ingestion into any future UI viewing application.

---

## 🚀 Compilation Speedup (Highly Recommended)

When testing these tiny edge cases, you do not need the History Buffer's full 64-step rollback capability. The massive width of the history BRAM (2080 bits per entry) is the absolute biggest bottleneck during Quartus Prime compilation.

To drastically expedite the Synthesis and Fitter stages while testing:
1. Open `rtl/memory/history_buffer.v`.
2. Change `parameter DEPTH = 64;` to `parameter DEPTH = 16;`.
3. Recompile.

> [!WARNING]
> Because every single test in the `edge_cases` directory (including the rollback tests) is intentionally engineered to be **under 10 instructions long**, reducing the depth to 16 guarantees that those tests will not be tainted and the rollback will function perfectly. 
> 
> **However**, the `primary_tests` are much longer (e.g., `reg_viewer_test` is 32 instructions). If you intend to run the primary tests and you want the ability to step backward all the way to the beginning of the program, you **must** use `DEPTH = 64`. If you use `DEPTH = 16`, the primary test will still execute perfectly forward, but you will only be able to rewind the last 16 steps.

### ⚠️ A Note on Data Memory Size
You might be tempted to shrink the `data_memory` from 128 bytes down to 16 bytes to further speed up compilation. **Do not do this for quick testing.**

Unlike the `DEPTH` parameter, the Data Memory size is **not a single variable change**. Because the History Buffer must take a 1-cycle snapshot of the entire processor, the Data Memory is serialized into a massive 1024-bit wide bus. Changing the memory capacity requires manually recalculating and modifying the bit-widths of `state_in` and `state_out` across `data_memory.v`, `history_buffer.v`, and the top-level modules. 

If you ever need to **expand** the memory for larger projects in the future, you must update the concatenation widths in all three of those files, otherwise the hardware rollback mechanism will shatter.

---

## 📁 Primary Tests (`tests/primary_tests/`)

These are the baseline tests used to verify standard CPU operation.

| Test Name | Description |
|-----------|-------------|
| `all_inst_test` | A mixed bag of instructions covering R, I, U, and S types to verify general datapath stability. |
| `memory_test` | A simple load/store test to verify the byte-lane architecture of the data memory. |
| `reg_viewer_test` | Executes 31 consecutive `ADDI` instructions to populate registers `x1` through `x31` with their own index numbers. Ideal for verifying the physical `SW[9:5]` hardware register viewer. |

---

## ⚠️ Edge Cases (`tests/edge_cases/`)

These 14 micro-tests are mathematically generated to stress-test specific borders of the RV32I architecture and the FPGA implementation.

### Architectural Constraints
- **`edge_x0_write`**: Attempts to write to `x0` via arithmetic, memory loads, and immediates to rigorously prove `x0` remains immutably `0`.
- **`edge_illegal_inst`**: Executes the undefined opcode `0xFFFFFFFF` to trigger the `E00002` (Illegal Instruction) Trap.

### Arithmetic Boundaries
- **`edge_arithmetic_wrap`**: Crosses the 32-bit arithmetic boundary by adding and subtracting around `0xFFFFFFFF` and `0x00000000`.
- **`edge_sign_ext_shift`**: Uses Arithmetic Shift Right (`SRAI`) versus Logical Shift Right (`SRLI`) on `0x80000000` to verify correct sign-bit propagation.
- **`edge_lui_auipc`**: Loads massive negative immediates via `LUI` and `AUIPC` to verify U-type upper-immediate zero-padding limits.

### Memory Boundaries
- **`edge_sign_ext_load`**: Loads `0x80` using `LB` (expecting `0xFFFFFF80`) and `LBU` (expecting `0x00000080`) to prove the data memory bridge correctly handles sign extension.
- **`edge_misaligned_load`**: Attempts a Word Load (`LW`) from the unaligned address `0x01` to trigger Trap `E00004`.
- **`edge_misaligned_store`**: Attempts a Word Store (`SW`) to the unaligned address `0x02` to trigger Trap `E00006`.
- **`edge_mem_bounds`**: Accesses address `124` (`0x7C`), the absolute highest valid word address in the 128-byte RAM block.

### Branching & Hazards
- **`edge_branch_negative`**: Uses `BNE` with a negative offset to prove the PC branch calculation supports two's-complement reverse jumps.
- **`edge_jal_jalr_extreme`**: Uses a massive positive `JAL` jump, followed by a negative `JALR` register-relative jump to test the bounds of the jump calculator and `ra` storage.
- **`edge_data_hazard`**: Continuously executes `ADD x1, x1, x1`. Even in a single-cycle core, this proves the asynchronous-read / synchronous-write paths in the Register File do not oscillate.

### Rollback (Undo) Verification
These tests specifically verify the hardware history buffer. The CSV files explicitly document the expected register and memory states during the reverse-execution phase.
- **`edge_rollback_regs`**: Steps forward to modify `x1`, `x2`, and `x3`, then steps backward. The CSV tracks the registers emptying back to zero.
- **`edge_rollback_mem`**: Stores `0xAA` to memory, overwrites it with `0xBB`, and rolls back. The test proves the old data is perfectly reinstated.

---

## 💻 Python VGA CSV Viewer

To make reviewing the CSV execution traces incredibly simple, this repository includes a native Python application (`tests/vga_viewer.py`) that visually mimics the physical FPGA VGA monitor!

**How to use it:**
1. Open your terminal or command prompt.
2. Navigate to the `tests/` directory.
3. Run the script: `python vga_viewer.py`
4. A file dialog will pop up. Select any of the `.csv` files from `primary_tests` or `edge_cases`.
5. The Pip-Boy UI will open.

**Controls:**
- ➡️ **Right Arrow Key**: Step Forward to the next instruction in the CSV trace.
- ⬅️ **Left Arrow Key**: Step Backward to the previous instruction.

The viewer will automatically render the 80x30 retro-green character grid, showing the Program Counter, the current instruction (both Hex and Assembly), the ALU Result, and the exact state of all 32 hardware registers at that specific moment in time!

---

## 🏗️ Von Neumann Tests (`tests/von_neumann_tests/`)

These tests verify the Unified Memory architecture where code and data share the same physical RAM block.

| Test Name | Description | Trace (.csv) |
|-----------|-------------|:------------:|
| `const_read` | Reads a 32-bit constant (`0xDEADBEEF`) from code. | ✅ |
| `data_write` | Stores a value to the unified RAM section. | ✅ |
| `trap_corruption` | Attempts to overwrite the Trap Handler code. | ✅ |
| `fibonacci.hex` | Calculates 10 numbers of Fibonacci sequence. | `x2`, `x3` values. |
| `halfword_test` | Tests 16-bit memory access (LH, LHU, SH). | `x3` (Sign ext), `x4` (Zero ext). |

### Half-word Test Details (`halfword_test`)
This test verifies the processor's ability to handle 16-bit data types, which is essential for working with short integers and audio/sensor data.

**Key Verification Points:**
1.  **Store Half (`sh`)**: Verifies that writing 16 bits to memory (e.g., at offset 2) doesn't corrupt the lower 16 bits of the same 32-bit word.
2.  **Load Half (`lh`)**: Tests sign extension. If the 16-bit value is negative (MSB=1), the register should be filled with `F`s (e.g., `0xABCD` -> `0xFFFFABCD`).
3.  **Load Half Unsigned (`lhu`)**: Tests zero extension. The same value `0xABCD` should result in `0x0000ABCD`.

### How to test Von Neumann Mode:
1. Ensure you have the **`FPGA-RiscV32I_VGA_VN`** revision selected in Quartus.
2. Replace `program.hex` with any of the files from this directory.
3. Recompile and deploy.
