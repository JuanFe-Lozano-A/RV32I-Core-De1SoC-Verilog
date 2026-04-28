`timescale 1ns / 1ps

module SingleCore_FPGA_RV32I (
    input wire FPGA_CLK,        // 50 MHz Clock
    input wire [3:0] KEY,       // Pushbuttons (Active Low)
    input wire [9:0] SW,        // Switches
    output wire [9:0] LEDR,     // Red LEDs
    output wire [6:0] HEX0,     // 7-segment displays
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5
);

    // ==========================================
    // 1. Clock, Reset & Step Logic
    // ==========================================
    // KEY[0] is Master Reset (Active Low)
    // KEY[1] is Step Forward (Active Low)
    // KEY[2] is Step Backward (Active Low)
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
    wire step_forward = ~key1_d1 & key1_d2;
    wire step_backward = ~key2_d1 & key2_d2;

    // ==========================================
    // 2. Interconnect Signals
    // ==========================================
    wire [31:0] imem_addr, imem_inst;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire dmem_we, dmem_re;
    wire [3:0] dmem_be;

    wire ram_sel, io_sel;
    wire [31:0] ram_rdata, io_rdata;

    // Hardware Monitor Signals
    wire [31:0] monitor_rd1, monitor_rd2;
    wire [31:0] monitor_mcause;
    wire [31:0] monitor_result;
    wire monitor_rs1_valid, monitor_rs2_valid, monitor_result_valid;
    wire monitor_trap_active;

    // Default IO rdata to 0 (no peripherals attached)
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
        .monitor_trap_active(monitor_trap_active)
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

    // Data Memory (RAM mapped to 0x0000_0000)
    data_memory u_dmem (
        .we(dmem_we & ram_sel),
        .re(dmem_re & ram_sel),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .be(dmem_be),
        .rdata(ram_rdata)
    );

    // ==========================================
    // 4. Hardware Monitor (HEX & LEDs)
    // ==========================================

    // is_trap: use latched register, NOT a PC address comparison
    // This prevents false triggering when normal code happens to pass through mtvec
    wire is_trap = monitor_trap_active;

    // LEDs
    assign LEDR[0] = (imem_addr == 32'd0);  // Beginning of program
    assign LEDR[1] = (imem_inst == 32'h0000006F); // End of program (Infinite loop JAL x0, 0)
    assign LEDR[9] = is_trap;               // Trap indicator
    assign LEDR[8:2] = 7'b0;                // Unused LEDs

    // HEX Display Multiplexer
    reg [23:0] display_val;
    reg display_en;
    always @(*) begin
        if (is_trap) begin
            // Error Display Mode: [E][ ][ ][ ][code]
            display_val = {4'hE, 16'h0000, monitor_mcause[3:0]}; 
            display_en = 1'b1;
        end else begin
            case (SW[2:0])
                3'b000: begin display_val = imem_addr[23:0];      display_en = 1'b1; end // 000: instr_addr (PC)
                3'b001: begin display_val = imem_inst[23:0];      display_en = 1'b1; end // 001: instr_bits
                3'b010: begin display_val = monitor_result[23:0]; display_en = monitor_result_valid; end // 010: Result
                3'b011: begin display_val = monitor_rd1[23:0];    display_en = monitor_rs1_valid; end // 011: reg_data1
                3'b100: begin display_val = monitor_rd2[23:0];    display_en = monitor_rs2_valid; end // 100: reg_data2
                default: begin display_val = 24'b0;               display_en = 1'b0; end
            endcase
        end
    end

    // HEX Decoders
    hex_decoder hd0 (.in(display_val[3:0]),   .en(display_en), .out(HEX0));
    hex_decoder hd1 (.in(display_val[7:4]),   .en(display_en), .out(HEX1));
    hex_decoder hd2 (.in(display_val[11:8]),  .en(display_en), .out(HEX2));
    hex_decoder hd3 (.in(display_val[15:12]), .en(display_en), .out(HEX3));
    hex_decoder hd4 (.in(display_val[19:16]), .en(display_en), .out(HEX4));
    hex_decoder hd5 (.in(display_val[23:20]), .en(display_en), .out(HEX5));

endmodule
