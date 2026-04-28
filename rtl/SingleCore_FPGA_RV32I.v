`timescale 1ns / 1ps

module SingleCore_FPGA_RV32I (
    input wire FPGA_CLK,        // 50 MHz Clock
    input wire [3:0] KEY,       // Pushbuttons (Active Low)
    input wire [9:0] SW,        // Switches
    output wire [9:0] LEDR,     // Red LEDs
    output wire [6:0] HEX0,     // 7-segment displays (HEX0=rightmost)
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5
);

    // ==========================================
    // 1. Clock, Reset & Step Logic
    // ==========================================
    // KEY[0] = Master Reset    (Active Low)
    // KEY[1] = Step Forward    (Active Low)
    // KEY[2] = Step Backward   (Active Low)
    wire RESET_N = KEY[0];

    reg key1_d1, key1_d2;
    reg key2_d1, key2_d2;
    always @(posedge FPGA_CLK or negedge RESET_N) begin
        if (!RESET_N) begin
            key1_d1 <= 1'b1;
            key1_d2 <= 1'b1;
            key2_d1 <= 1'b1;
            key2_d2 <= 1'b1;
        end else begin
            key1_d1 <= KEY[1];
            key1_d2 <= key1_d1;
            key2_d1 <= KEY[2];
            key2_d2 <= key2_d1;
        end
    end

    // Pulse on falling edge
    wire step_forward  = ~key1_d1 & key1_d2;
    wire step_backward = ~key2_d1 & key2_d2;

    // ==========================================
    // 2. Interconnect Signals
    // ==========================================
    wire [31:0] imem_addr, imem_inst;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire        dmem_we, dmem_re;
    wire [3:0]  dmem_be;

    wire        ram_sel, io_sel;
    wire [31:0] ram_rdata, io_rdata;

    // Hardware Monitor Signals
    wire [31:0]  monitor_rd1, monitor_rd2;
    wire [31:0]  monitor_mcause;
    wire [31:0]  monitor_result;
    wire         monitor_rs1_valid, monitor_rs2_valid, monitor_result_valid;
    wire         monitor_trap_active;
    wire [1023:0] monitor_regfile_state;

    // Data Memory ↔ Core snapshot/restore wires
    wire [1023:0] dmem_state_out;
    wire          dmem_restore_en;
    wire [1023:0] dmem_restore_data;

    // Default IO rdata to 0 (no peripherals attached yet)
    assign io_rdata = 32'b0;

    // ==========================================
    // 3. Submodule Instantiation
    // ==========================================

    // Instruction Memory
    instruction_memory u_imem (
        .addr(imem_addr),
        .inst(imem_inst)
    );

    // RV32I Core
    rv32i_core u_core (
        .clk(FPGA_CLK),
        .reset_n(RESET_N),
        .step_forward(step_forward),
        .step_backward(step_backward),
        .imem_addr(imem_addr),
        .imem_inst(imem_inst),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_we(dmem_we),
        .dmem_re(dmem_re),
        .dmem_be(dmem_be),
        .monitor_rd1(monitor_rd1),
        .monitor_rd2(monitor_rd2),
        .monitor_mcause(monitor_mcause),
        .monitor_result(monitor_result),
        .monitor_rs1_valid(monitor_rs1_valid),
        .monitor_rs2_valid(monitor_rs2_valid),
        .monitor_result_valid(monitor_result_valid),
        .monitor_trap_active(monitor_trap_active),
        .monitor_regfile_state(monitor_regfile_state),
        .dmem_state_in(dmem_state_out),
        .dmem_restore_en(dmem_restore_en),
        .dmem_restore_data(dmem_restore_data)
    );

    // Address Bridge
    address_bridge u_bridge (
        .addr(dmem_addr),
        .MemRead(dmem_re),
        .MemWrite(dmem_we),
        .ram_sel(ram_sel),
        .ram_rdata(ram_rdata),
        .io_sel(io_sel),
        .io_rdata(io_rdata),
        .rdata_out(dmem_rdata)
    );

    // Data Memory (async latches, 128 bytes, four 8-bit banks)
    data_memory u_dmem (
        .clk(FPGA_CLK),
        .we(dmem_we & ram_sel),
        .re(dmem_re & ram_sel),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .be(dmem_be),
        .rdata(ram_rdata),
        .restore_en(dmem_restore_en),
        .restore_data(dmem_restore_data),
        .state_out(dmem_state_out)
    );

    // ==========================================
    // 4. Hardware Monitor (HEX & LEDs)
    // ==========================================

    wire is_trap = monitor_trap_active;

    // LEDs
    assign LEDR[0] = (imem_addr == 32'd0);           // Start of program
    assign LEDR[1] = (imem_inst == 32'h0000006F);    // End (infinite JAL x0,0)
    assign LEDR[9] = is_trap;                         // Trap/error indicator
    assign LEDR[8:2] = 7'b0;

    // ==========================================
    // 5. HEX Display Multiplexer
    // ==========================================
    //
    // SW[2:0] — Display mode:
    //   000 = PC (program counter)
    //   001 = Current instruction bits
    //   010 = ALU / write-back result
    //   011 = rs1 data
    //   100 = rs2 data
    //   101 = Register file viewer (register selected by SW[9:5])
    //
    // SW[3]   — Upper byte modifier:
    //   0 = Normal: HEX5:HEX0 show bits [23:0]  of selected value
    //   1 = Upper:  HEX1:HEX0 show bits [31:24], HEX5:HEX2 are blanked
    //
    // SW[9:5] — Register select (0–31 = x0–x31), active when SW[2:0]=101
    //
    // TRAP mode overrides all of the above:
    //   HEX5='E', HEX4:1='0000', HEX0=mcause nibble

    wire [4:0]  reg_sel      = SW[9:5];
    wire [31:0] selected_reg = monitor_regfile_state[reg_sel*32 +: 32];
    wire        upper_mode   = SW[3];

    reg [31:0] display_val_full;
    reg        display_en;

    always @(*) begin
        display_en = 1'b1;
        if (is_trap) begin
            // Error layout: [00][E][000][mcause_nibble]
            // Upper byte = 0x00, Normal: HEX5='E', HEX0=cause
            display_val_full = {8'h00, 4'hE, 16'h0000, monitor_mcause[3:0]};
        end else begin
            case (SW[2:0])
                3'b000: begin display_val_full = imem_addr;       display_en = 1'b1;                end
                3'b001: begin display_val_full = imem_inst;       display_en = 1'b1;                end
                3'b010: begin display_val_full = monitor_result;  display_en = monitor_result_valid; end
                3'b011: begin display_val_full = monitor_rd1;     display_en = monitor_rs1_valid;    end
                3'b100: begin display_val_full = monitor_rd2;     display_en = monitor_rs2_valid;    end
                3'b101: begin display_val_full = selected_reg;    display_en = 1'b1;                end
                default: begin display_val_full = 32'b0;          display_en = 1'b0;                end
            endcase
        end
    end

    // Split the 32-bit value into lower 24 bits (normal) and upper 8 bits (upper_mode)
    wire [23:0] display_lower = display_val_full[23:0];
    wire [7:0]  display_upper = display_val_full[31:24];

    // HEX Decoders
    // HEX0 & HEX1: show lower nibbles normally; show upper byte when upper_mode=1
    // HEX2–HEX5:   show lower nibbles normally; blanked when upper_mode=1
    hex_decoder hd0 (.in(upper_mode ? display_upper[3:0] : display_lower[3:0]),  .en(display_en),                      .out(HEX0));
    hex_decoder hd1 (.in(upper_mode ? display_upper[7:4] : display_lower[7:4]),  .en(display_en),                      .out(HEX1));
    hex_decoder hd2 (.in(display_lower[11:8]),                                    .en(upper_mode ? 1'b0 : display_en), .out(HEX2));
    hex_decoder hd3 (.in(display_lower[15:12]),                                   .en(upper_mode ? 1'b0 : display_en), .out(HEX3));
    hex_decoder hd4 (.in(display_lower[19:16]),                                   .en(upper_mode ? 1'b0 : display_en), .out(HEX4));
    hex_decoder hd5 (.in(display_lower[23:20]),                                   .en(upper_mode ? 1'b0 : display_en), .out(HEX5));

endmodule
