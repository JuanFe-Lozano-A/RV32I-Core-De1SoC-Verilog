# Scratch Scripts (`scratch/`)

This directory contains the Python utility scripts used to generate the data files, ROMs, and test vectors required by the hardware. Because Verilog is designed for describing physical circuits rather than complex data processing, Python is the industry-standard tool used as a "factory" to build these assets.

## Files & Responsibilities

### `gen_tests.py`
The Automated Mathematical Simulator.
- **What it does:** This script acts as a miniature, software-based RV32I emulator. It contains the logic for 14 different architectural "edge cases" (e.g., arithmetic wrapping, illegal instructions, memory bounds). When executed, it simulates the execution of these assembly instructions step-by-step.
- **Outputs:** It mathematically calculates the exact state of all 32 registers at every step and writes the resulting execution trace to massive `.csv` files (used by the Python VGA viewer). It also outputs the raw machine code to `.hex` files, which Quartus directly loads into the FPGA's Instruction Memory during synthesis.

### `gen_font.py`
The VGA Font Generator.
- **What it does:** The FPGA's VGA `text_engine` needs to know what pixels to turn on to draw the letter "A". This script uses the Python Imaging Library (PIL) to parse a real TrueType font and extract the pixel shapes into a raw binary bitmask.
- **Outputs:** It prints out the Verilog case statement arrays needed to populate the `rtl/vga/font_rom.v` module. 

### `gen_text_engine.py`
The Display Coordinate Mapper.
- **What it does:** The `text_engine` displays an 80x30 grid of characters. This script was used to calculate the exact `(x, y)` coordinate bounding boxes for every single UI element on the screen (e.g., calculating exactly which characters should form the border of the Register grid).
- **Outputs:** It prints out raw Verilog combinational logic (`if x > 10 and y < 5`) that was then copy-pasted into `rtl/vga/text_engine.v` to define the screen layout.
