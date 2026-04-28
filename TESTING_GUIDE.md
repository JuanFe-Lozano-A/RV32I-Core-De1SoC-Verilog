# FPGA RISC-V Testing Guide

This guide explains how to use the automated testbench to mathematically verify the entire top-level design (including the physical FPGA components) using Icarus Verilog.

## The Integration Testbench
The file `tb/integration_test_tb.v` is the master simulation file for this project. Unlike standard processor testbenches, this testbench **instantiates the Top-Level FPGA module (`SingleCore_FPGA_RV32I.v`)**. 

It does not just look at internal processor states; it literally simulates pressing the physical buttons (`KEY`) and flipping the physical switches (`SW`) to verify that the 7-segment displays (`HEX`) and `LEDR` outputs behave exactly as they will on your real DE1-SoC board.

### What the test verifies:
1. **Instruction Set Exhaustion**: It runs a heavily loaded `program.hex` that utilizes every Base Integer RV32I instruction (R-type, I-type, U-type, B-type, J-type, Load/Store).
2. **Switch UI Logic**: It simulates flipping the first three switches (`SW[2:0]`) and asserts that the hex display accurately decodes the Program Counter and Instruction bits.
3. **Undo Functionality**: It simulates pressing `KEY[2]` (Step Backward) 5 consecutive times, then verifies that the Program Counter properly reverted via the internal BRAM history buffer.
4. **Memory Resource Bounds Check**: It calculates and prints the exact physical BRAM footprint required by the DE1-SoC for this architecture, proving that the History Buffer and memory constraints are incredibly safe (uses < 2% of total board BRAM).

## Running the Simulation

If you have Icarus Verilog (`iverilog`) installed on your system, you can run the test suite by executing the following commands in your terminal from the project root:

```powershell
# 1. Find all Verilog files and compile them into a simulation binary
$files = Get-ChildItem -Path ./rtl -Recurse -Filter *.v | ForEach-Object { $_.FullName }
iverilog -g2009 -o tb/integration_sim tb/integration_test_tb.v $files

# 2. Run the compiled simulation
vvp tb/integration_sim
```

### Understanding the Output
If everything is wired correctly, you will see an output similar to this:
```text
==================================================
   STARTING COMPREHENSIVE FPGA INTEGRATION TEST   
==================================================
-> Sending System Reset via KEY[0]...
PASS: LEDR[0] correctly lit at PC=0

-> Stepping forward 10 instructions...

-> Testing Physical Switch UI logic...
PASS: SW[0] correctly shows PC
PASS: SW[1] correctly shows Instruction

-> Testing Undo functionality (KEY[2])...
   Currently at PC=40. Reversing 5 steps...
PASS: Undo buffer successfully reverted state.

-> Running remaining instructions to completion...
PASS: Execution reached standard Exit Loop correctly.

==================================================
             MEMORY UTILIZATION REPORT            
==================================================
- DE1-SoC Total BRAM:     ~4,000,000 bits
- Instruction Memory:     2,048 bits (64 words)
- Data Memory:            8,192 bits (256 words)
- History Buffer:         67,584 bits (64 entries)
- TOTAL DESIGN USAGE:     77,824 bits
--------------------------------------------------
-> The total BRAM utilized is ~1.94% of capacity.
-> PASS: Memory utilization is extremely safe.
==================================================
```

## Making Your Own Tests
To write your own test program, you can manually write hex instructions or use the provided Python assembler.

1. Open `tb/assembler.py`.
2. Add your instructions to the `instructions = []` list using the helper functions (`encode_r`, `encode_i`, etc.).
3. Run `python tb/assembler.py`.
4. The script will automatically generate `program.hex` for you! Re-run the simulation to test your new code.
