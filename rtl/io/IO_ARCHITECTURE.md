# RV32I I/O Subsystem (`rtl/io/`)

This directory contains the driver logic for physical peripherals on the DE1-SoC board, primarily the 7-segment displays.

## Files & Responsibilities

### `hex_decoder.v`
The 7-Segment Display Driver.
- **What it does:** It takes a 4-bit binary nibble (values `0x0` through `0xF`) and translates it into the 7-bit physical wire signals required to illuminate the corresponding hexadecimal character on a 7-segment display. The DE1-SoC uses *active-low* displays, meaning a `0` turns a segment ON and a `1` turns a segment OFF. This module handles that inversion.
- **Connections:** It is instantiated multiple times in the top-level wrapper (`SingleCore_FPGA_RV32I.v`) to drive the `HEX0` through `HEX5` physical pins on the FPGA, translating the 32-bit internal data buses into human-readable output.
