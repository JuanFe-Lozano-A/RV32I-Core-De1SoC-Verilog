`timescale 1ns / 1ps
module ebreak_diag_tb;
    reg FPGA_CLK;
    reg [3:0] KEY;
    reg [9:0] SW;
    wire [9:0] LEDR;
    wire [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;

    SingleCore_FPGA_RV32I uut(.FPGA_CLK(FPGA_CLK),.KEY(KEY),.SW(SW),.LEDR(LEDR),
        .HEX0(HEX0),.HEX1(HEX1),.HEX2(HEX2),.HEX3(HEX3),.HEX4(HEX4),.HEX5(HEX5));

    always #10 FPGA_CLK = ~FPGA_CLK;

    task fwd;
        begin KEY[1]=0; #40; KEY[1]=1; #40; end
    endtask

    integer i;
    initial begin
        FPGA_CLK=0; KEY=4'b1111; SW=10'd0;
        KEY[0]=0; #50; KEY[0]=1; #50;

        // Step through every instruction, printing state
        for (i = 0; i < 42; i = i + 1) begin
            $display("BEFORE step %2d: PC=%3h  inst=%8h  trap=%b  trap_active=%b  mcause=%0d  MemWrite=%b  dmem_addr=%8h  alu_result=%8h",
                i,
                uut.u_core.pc_out,
                uut.u_core.imem_inst,
                uut.u_core.trap,
                uut.u_core.trap_active,
                uut.u_core.mcause,
                uut.u_core.dmem_we,
                uut.u_core.dmem_addr,
                uut.u_core.alu_result
            );
            fwd();
        end

        $display("\n--- FINAL STATE ---");
        $display("PC=%h  mcause=%0d  trap_active=%b", 
            uut.u_core.pc_out, uut.u_core.mcause, uut.u_core.trap_active);
        $finish;
    end
endmodule
