`timescale 1ns / 1ps
module verify_mem_tb;
    reg clk; always #10 clk = ~clk;
    reg [3:0] KEY; reg [9:0] SW; wire [9:0] LEDR; wire [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;
    SingleCore_FPGA_RV32I uut(.FPGA_CLK(clk),.KEY(KEY),.SW(SW),.LEDR(LEDR),.HEX0(HEX0),.HEX1(HEX1),.HEX2(HEX2),.HEX3(HEX3),.HEX4(HEX4),.HEX5(HEX5));
    task step; begin KEY[1]=0; #40; KEY[1]=1; #40; end endtask
    integer i;
    initial begin
        clk=0; KEY=4'hF; SW=10'd0;
        KEY[0]=0; #50; KEY[0]=1; #50;
        $display("=== TEST 2: Memory Store/Load Test ===");
        $display("PC         | Instruction | Result     | rs1        | rs2");
        for (i=0; i<16; i=i+1) begin
            $display("0x%8h | %h  | %h | %h | %h",
                uut.u_core.pc_out, uut.u_core.imem_inst,
                uut.u_core.reg_write_data, uut.u_core.rd1, uut.u_core.rd2);
            step();
        end
        $display("\nFinal register dump (x1..x11):");
        for (i=1; i<=11; i=i+1)
            $display("  x%0d = 0x%h", i, uut.u_core.u_regfile.registers[i]);
        $display("\nMemory word 0 = 0x%h  (expect 0x12345678)",
            {uut.u_dmem.bank3[0], uut.u_dmem.bank2[0], uut.u_dmem.bank1[0], uut.u_dmem.bank0[0]});
        $display("LEDR[1] (halt)=%b", LEDR[1]);
        $finish;
    end
endmodule
