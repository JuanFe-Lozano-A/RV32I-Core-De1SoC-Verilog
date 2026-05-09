# VGA Subsystem (`rtl/vga/`)

This directory contains the logic for real-time visual debugging of the RISC-V processor on a standard VGA monitor.

## Components

### `vga_controller.v`
The timing engine for the VGA signal.
- **Resolution**: 640x480 @ 60Hz.
- **Function**: Generates the `H-Sync`, `V-Sync`, and `video_on` signals. It provides the current `pixel_x` and `pixel_y` coordinates to the text engine.

### `font_rom.v`
A 2KB ROM containing an 8x16 bitmapped font.
- **Function**: Given an ASCII character code and a scanline (0-15), it returns the 8-bit pattern of pixels for that row of the character.

### `text_engine.v`
The character renderer and dashboard.
- **Function**: It receives the entire CPU state (PC, Instructions, Registers, ALU result) and maps it to specific grid locations on the screen.
- **Layout**:
    - **Line 1-4**: General CPU status (PC, Instruction Hex).
    - **Line 6-10**: Specific ALU/Branch monitoring (RS1, RS2, ALU Result).
    - **Right Side**: Full Register File dump (x0 - x31).
- **Features**:
    - Displays `OFF` when signals (like RS1/RS2) are invalid for the current instruction.
    - Highlights `TRAP` states when a syscall or error occurs.

## Connections

The VGA subsystem is clocked at 25 MHz (divided from the 50 MHz FPGA clock). It connects directly to the top-level monitor buses from the `rv32i_core.v`.

## Usage in Revisions
This subsystem is included in both the **Harvard** and **Von Neumann** revisions.
