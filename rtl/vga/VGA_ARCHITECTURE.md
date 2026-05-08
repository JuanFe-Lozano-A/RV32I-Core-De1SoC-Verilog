# RV32I VGA Subsystem (`rtl/vga/`)

This directory contains the hardware logic required to drive an external monitor via the DE1-SoC's VGA DAC. It provides a real-time, retro Pip-Boy style visualization of the entire internal state of the processor.

## Files & Responsibilities

### `vga_controller.v`
The Sync and Timing Generator.
- **What it does:** Using a 25MHz clock, this module mathematically calculates the exact pixel coordinates (`x`, `y`) currently being drawn by the monitor's electron beam. It generates the industry-standard 640x480 @ 60Hz timing signals, including the Horizontal Sync (`VGA_HS`), Vertical Sync (`VGA_VS`), and Blanking intervals. 
- **Connections:** It interfaces directly with the physical VGA pins on the FPGA and outputs the `x` and `y` coordinates to the `text_engine.v` so it knows which pixel to color.

### `font_rom.v`
The Visual Character Dictionary.
- **What it does:** A Read-Only Memory containing the pixel bitmasks for the ASCII character set. Every character is 8 pixels wide and 16 pixels tall. When given an ASCII code and a specific Y-row, it outputs an 8-bit row of pixels that represent that slice of the letter.
- **Connections:** It is instantiated exclusively by the `text_engine.v`.

### `text_engine.v`
The Pip-Boy Graphics Renderer.
- **What it does:** This is the core visualization logic. It takes the current `x` and `y` pixel coordinates from the `vga_controller` and determines which character should be drawn at that exact spot on an 80x30 character grid. It actively monitors the `state_out` buses of the Register File, Program Counter, ALU, and Control Unit. By converting those 32-bit hex values into ASCII characters on the fly, it renders the entire CPU state to the screen in a retro green (`#39FF14`) color palette.
- **Connections:** It reads data from almost every major module in the top-level design, queries the `font_rom.v` for character pixels, and outputs the final RGB color values back to the `vga_controller.v` interface.
