# System-on-Chip (SoC) Architecture

This document explains how the individual components of the RISC-V project are interconnected at the top level in `SingleCore_FPGA_RV32I_VGA.v`.

## Block Diagram

The SoC integrates the **RV32I Core** with memory, I/O peripherals, and a dedicated VGA monitoring system.

## Dual-Architecture Mode

The system can be compiled in two different configurations using Quartus Revisions:

### 1. Harvard Mode (Default)
- **Top-Level Logic**: Instantiates `instruction_memory` and `data_memory` separately.
- **Data Flow**: Instructions are fetched from ROM; data is read/written to a blank-start RAM.
- **Use Case**: Standard RISC-V testing and code execution.

### 2. Von Neumann Mode
- **Top-Level Logic**: Instantiates a single `unified_memory` module.
- **Data Flow**: The CPU uses two ports of the same RAM to access both code and data.
- **Use Case**: Complex programs with `.data` sections or self-modifying code (simulated).
- **Control**: Activated by the Verilog macro ``USE_VON_NEUMANN``.

## Peripherals and I/O

The system uses an **Address Bridge** to map addresses above `0x2000` to external hardware:
- **0x2000 - 0x200F**: Reserved for HEX displays and LEDs.
- **VGA Monitor**: Receives a real-time copy of the core's internal state (PC, registers, etc.) regardless of the memory architecture selected.

## Clocking

- **FPGA_CLK**: 50 MHz (Main system clock for the Core and Memory).
- **VGA_CLK**: 25 MHz (Divided clock for stable video signal).

## How to switch
Refer to `rtl/memory/MEMORY_ARCHITECTURE.md` for detailed instructions on switching between revisions in Intel Quartus.
