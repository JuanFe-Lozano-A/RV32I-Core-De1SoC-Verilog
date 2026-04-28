`timescale 1ns / 1ps

module rv32i_core (
    input wire clk,
    input wire reset_n,
    input wire step_forward,
    input wire step_backward,
    
    // Instruction Memory Interface
    output wire [31:0] imem_addr,
    input wire [31:0] imem_inst,
    
    // Data Memory Interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input wire [31:0] dmem_rdata,
    output wire dmem_we,
    output wire dmem_re,
    output reg [3:0] dmem_be, // Byte Enable
    
    // Hardware Monitor Interface
    output wire [31:0] monitor_rd1,
    output wire [31:0] monitor_rd2,
    output wire [31:0] monitor_mcause,
    output wire [31:0] monitor_result,
    output wire monitor_rs1_valid,
    output wire monitor_rs2_valid,
    output wire monitor_result_valid,
    output wire monitor_trap_active
);

    // ==========================================
    // Core Datapath Signals
    // ==========================================
    wire [31:0] pc_out, pc_next, pc_plus_4, branch_target;
    wire [31:0] rd1, rd2;
    wire [31:0] alu_result;
    wire [31:0] imm;
    
    wire RegWrite, ALUSrc, Branch, Jump, MemRead, MemWrite, MemToReg, IllegalInst, JALR_flag, Syscall;
    wire [1:0] ALUSrcA;
    wire [2:0] ImmSel;
    wire [1:0] ALUOp;
    wire [3:0] alu_op_ctrl;
    wire alu_zero;
    wire branch_taken;

    // ==========================================
    // Temporal Control FSM & History Buffer
    // ==========================================
    localparam STATE_IDLE = 2'd0;
    localparam STATE_BWD1 = 2'd1;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) state <= STATE_IDLE;
        else state <= next_state;
    end

    wire [1023:0] current_regfile_state;
    wire [1023:0] restored_regfile_state;
    wire [31:0] restored_pc;
    wire hist_empty;
    wire [1055:0] hist_state_out;
    
    assign restored_pc = hist_state_out[1055:1024];
    assign restored_regfile_state = hist_state_out[1023:0];

    reg hist_push, hist_pop;
    reg core_step, core_restore;

    always @(*) begin
        next_state = state;
        hist_push = 1'b0;
        hist_pop = 1'b0;
        core_step = 1'b0;
        core_restore = 1'b0;

        case (state)
            STATE_IDLE: begin
                if (step_forward) begin
                    hist_push = 1'b1;
                    core_step = 1'b1;
                end else if (step_backward && !hist_empty) begin
                    hist_pop = 1'b1;
                    next_state = STATE_BWD1;
                end
            end
            STATE_BWD1: begin
                // BRAM read takes 1 cycle, data is ready now
                core_restore = 1'b1;
                next_state = STATE_IDLE;
            end
            default: next_state = STATE_IDLE;
        endcase
    end

    history_buffer u_hist (
        .clk(clk),
        .reset_n(reset_n),
        .push(hist_push),
        .pop(hist_pop),
        .state_in({pc_out, current_regfile_state}),
        .state_out(hist_state_out),
        .empty(hist_empty)
    );

    // ==========================================
    // Exception & Trap Logic (CSRs)
    // ==========================================
    wire [2:0] funct3 = imem_inst[14:12];

    wire misaligned_word = (funct3[1:0] == 2'b10) && (alu_result[1:0] != 2'b00);
    wire misaligned_half = (funct3[1:0] == 2'b01) && (alu_result[0] != 1'b0);
    wire MisalignedLoad = MemRead && (misaligned_word || misaligned_half);
    wire MisalignedStore = MemWrite && (misaligned_word || misaligned_half);
    
    wire trap = IllegalInst | MisalignedLoad | MisalignedStore | Syscall;
    wire [31:0] trap_cause = Syscall ? (imem_inst[20] ? 32'd3 : 32'd11) : (IllegalInst ? 32'd2 : (MisalignedLoad ? 32'd4 : 32'd6));

    reg [31:0] mepc;
    reg [31:0] mcause;
    reg trap_active;                   // Latched: stays HIGH until reset
    wire [31:0] mtvec = 32'h000000FC; // Trap handler: last ROM slot (index 63)

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            mepc        <= 32'b0;
            mcause      <= 32'b0;
            trap_active <= 1'b0;
        end else if (core_step && trap && !trap_active) begin
            // Latch on first trap only; don't re-trap inside the handler
            mepc        <= pc_out;
            mcause      <= trap_cause;
            trap_active <= 1'b1;
        end
    end

    // ==========================================
    // Datapath Routing & Overrides
    // ==========================================
    
    // Override writes to prevent state corruption on trap
    wire effective_MemWrite = MemWrite & ~trap;
    wire effective_RegWrite = RegWrite & ~trap;

    // Next PC logic overrides
    assign pc_plus_4 = pc_out + 32'd4;
    assign branch_target = pc_out + imm;
    wire [31:0] jalr_target = (rd1 + imm) & ~32'b1;
    wire [31:0] normal_pc_next = JALR_flag ? jalr_target : ((Jump || (Branch && branch_taken)) ? branch_target : pc_plus_4);
    
    assign pc_next = (trap && !trap_active) ? mtvec : normal_pc_next;
    assign imem_addr = pc_out;

    // Program Counter
    pc u_pc (
        .clk(clk), 
        .reset_n(reset_n), 
        .step(core_step), 
        .pc_in(pc_next), 
        .pc_out(pc_out),
        .restore_en(core_restore),
        .restore_pc(restored_pc)
    );

    // Control Unit
    control_unit u_ctrl (
        .opcode(imem_inst[6:0]),
        .Branch(Branch),
        .Jump(Jump),
        .JALR_flag(JALR_flag),
        .MemRead(MemRead),
        .MemToReg(MemToReg),
        .ALUOp(ALUOp),
        .MemWrite(MemWrite),
        .ALUSrc(ALUSrc),
        .ALUSrcA(ALUSrcA),
        .RegWrite(RegWrite),
        .ImmSel(ImmSel),
        .Syscall(Syscall),
        .Rs1Valid(monitor_rs1_valid),
        .Rs2Valid(monitor_rs2_valid),
        .IllegalInst(IllegalInst)
    );

    // Memory Interface
    assign dmem_addr = alu_result;
    assign dmem_we = effective_MemWrite & core_step;
    assign dmem_re = MemRead;

    // Byte Enable Generation (combinational)
    always @(*) begin
        if (effective_MemWrite || MemRead) begin
            case (funct3[1:0])
                2'b00: dmem_be = 4'b0001 << alu_result[1:0]; // Byte
                2'b01: dmem_be = 4'b0011 << alu_result[1:0]; // Halfword
                2'b10: dmem_be = 4'b1111;                    // Word
                default: dmem_be = 4'b1111;
            endcase
        end else begin
            dmem_be = 4'b0000;
        end
    end

    // Write Data Alignment (shift data to correct byte lane)
    assign dmem_wdata = rd2 << (8 * alu_result[1:0]);

    // Read Data Alignment & Sign Extension
    reg [31:0] aligned_rdata;
    always @(*) begin
        aligned_rdata = dmem_rdata >> (8 * alu_result[1:0]);
        case (funct3)
            3'b000: aligned_rdata = {{24{aligned_rdata[7]}}, aligned_rdata[7:0]};  // LB
            3'b001: aligned_rdata = {{16{aligned_rdata[15]}}, aligned_rdata[15:0]}; // LH
            3'b010: aligned_rdata = aligned_rdata;                                 // LW
            3'b100: aligned_rdata = {24'b0, aligned_rdata[7:0]};                   // LBU
            3'b101: aligned_rdata = {16'b0, aligned_rdata[15:0]};                  // LHU
            default: aligned_rdata = aligned_rdata;
        endcase
    end

    // Register File Write Data Mux
    wire [31:0] reg_write_data = Jump ? pc_plus_4 : (MemToReg ? aligned_rdata : alu_result);

    // Register File
    register_file u_regfile (
        .we(effective_RegWrite & core_step), 
        .rs1(imem_inst[19:15]),
        .rs2(imem_inst[24:20]),
        .rd(imem_inst[11:7]),
        .wd(reg_write_data),
        .rd1(rd1),
        .rd2(rd2),
        .restore_en(core_restore),
        .restore_in(restored_regfile_state),
        .state_out(current_regfile_state)
    );

    // Expose for hardware monitoring
    assign monitor_rd1          = rd1;
    assign monitor_rd2          = rd2;
    assign monitor_mcause       = mcause;
    assign monitor_result       = reg_write_data;
    assign monitor_result_valid = effective_RegWrite;
    assign monitor_trap_active  = trap_active;

    // Immediate Generator
    imm_gen u_imm_gen (.inst(imem_inst[31:7]), .ImmSel(ImmSel), .imm(imm));

    // ALU Control
    alu_control u_alu_ctrl (.ALUOp(ALUOp), .funct3(funct3), .funct7_5(imem_inst[30]), .op(alu_op_ctrl));

    // ALU
    wire [31:0] alu_operand_a = (ALUSrcA == 2'b01) ? pc_out : ((ALUSrcA == 2'b10) ? 32'b0 : rd1);
    wire [31:0] alu_operand_b = ALUSrc ? imm : rd2;
    alu u_alu (.op(alu_op_ctrl), .a(alu_operand_a), .b(alu_operand_b), .result(alu_result), .zero(alu_zero));

    // Branch Unit
    branch_unit u_branch_unit (.a(rd1), .b(rd2), .funct3(funct3), .branch_taken(branch_taken));

endmodule
