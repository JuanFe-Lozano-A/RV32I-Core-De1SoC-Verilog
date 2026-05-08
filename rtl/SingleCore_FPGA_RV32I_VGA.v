`timescale 1ns / 1ps

module SingleCore_FPGA_RV32I_VGA (
    input wire FPGA_CLK,        // 50 MHz Clock
    input wire [3:0] KEY,       // Pushbuttons (Active Low)
    input wire [9:0] SW,        // Switches
    output wire [9:0] LEDR,     // Red LEDs
    output wire [6:0] HEX0,     // 7-segment displays (HEX0=rightmost)
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,
    
    // VGA Interface
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS,
    output wire       VGA_CLK,
    output wire       VGA_SYNC_N,
    output wire       VGA_BLANK_N
);

    // ==========================================
    // 1. Clock Divider (50 MHz -> 25 MHz)
    // ==========================================
    reg clk_25mhz = 0;
    always @(posedge FPGA_CLK) begin
        clk_25mhz <= ~clk_25mhz;
    end
    assign VGA_CLK = ~clk_25mhz;

    // ==========================================
    // 2. Clock, Reset & Step Logic
    // ==========================================
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

    wire step_forward  = ~key1_d1 & key1_d2;
    wire step_backward = ~key2_d1 & key2_d2;

    // ==========================================
    // 3. Interconnect Signals
    // ==========================================
    wire [31:0] imem_addr, imem_inst;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire        dmem_we, dmem_re;
    wire [3:0]  dmem_be;

    wire        ram_sel, io_sel;
    wire [31:0] ram_rdata, io_rdata;

    wire [31:0]  monitor_rd1, monitor_rd2;
    wire [31:0]  monitor_mcause;
    wire [31:0]  monitor_result;
    wire         monitor_rs1_valid, monitor_rs2_valid, monitor_result_valid;
    wire         monitor_trap_active;
    wire [1023:0] monitor_regfile_state;

    wire [1023:0] dmem_state_out;
    wire          dmem_restore_en;
    wire [1023:0] dmem_restore_data;

    assign io_rdata = 32'b0;

    // ==========================================
    // 4. Submodule Instantiation
    // ==========================================

    instruction_memory u_imem (
        .addr(imem_addr),
        .inst(imem_inst)
    );

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
    // 5. Hardware Monitor (HEX & LEDs)
    // ==========================================
    wire is_trap = monitor_trap_active;
    wire is_first_inst = (imem_addr == 32'd0);
    wire is_last_inst = (imem_inst == 32'h0000006F);

    assign LEDR[0] = is_first_inst;
    assign LEDR[1] = is_last_inst;
    assign LEDR[9] = is_trap;
    assign LEDR[8:2] = 7'b0;

    wire [4:0]  reg_sel      = SW[9:5];
    wire [31:0] selected_reg = monitor_regfile_state[reg_sel*32 +: 32];
    wire        upper_mode   = SW[3];

    reg [31:0] display_val_full;
    reg        display_en;

    always @(*) begin
        display_en = 1'b1;
        if (is_trap) begin
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

    wire [23:0] display_lower = display_val_full[23:0];
    wire [7:0]  display_upper = display_val_full[31:24];

    hex_decoder hd0 (.in(upper_mode ? display_upper[3:0] : display_lower[3:0]),  .en(display_en),                      .out(HEX0));
    hex_decoder hd1 (.in(upper_mode ? display_upper[7:4] : display_lower[7:4]),  .en(display_en),                      .out(HEX1));
    hex_decoder hd2 (.in(display_lower[11:8]),                                    .en(upper_mode ? 1'b0 : display_en), .out(HEX2));
    hex_decoder hd3 (.in(display_lower[15:12]),                                   .en(upper_mode ? 1'b0 : display_en), .out(HEX3));
    hex_decoder hd4 (.in(display_lower[19:16]),                                   .en(upper_mode ? 1'b0 : display_en), .out(HEX4));
    hex_decoder hd5 (.in(display_lower[23:20]),                                   .en(upper_mode ? 1'b0 : display_en), .out(HEX5));

    // ==========================================
    // 6. VGA Subsystem
    // ==========================================
    wire [9:0] pixel_x, pixel_y;
    wire video_on;

    vga_controller u_vga_ctrl (
        .clk_25mhz(clk_25mhz),
        .reset_n(RESET_N),
        .hsync(VGA_HS),
        .vsync(VGA_VS),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    // Standard DE1-SoC VGA blanking/sync signals
    assign VGA_BLANK_N = video_on;
    assign VGA_SYNC_N  = 1'b0;

    text_engine u_text_engine (
        .clk(clk_25mhz),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .sw_4_enable(SW[4]), // Using SW[4] to enable/disable VGA (Pip-Boy mode)
        .pc_out(imem_addr),
        .imem_inst(imem_inst),
        .monitor_regfile_state(monitor_regfile_state),
        .monitor_rd1(monitor_rd1),
        .monitor_rd2(monitor_rd2),
        .monitor_result(monitor_result),
        .trap_active(monitor_trap_active),
        .mcause(monitor_mcause[3:0]),
        .is_first_inst(is_first_inst),
        .is_last_inst(is_last_inst),
        .red(VGA_R),
        .green(VGA_G),
        .blue(VGA_B)
    );

endmodule
