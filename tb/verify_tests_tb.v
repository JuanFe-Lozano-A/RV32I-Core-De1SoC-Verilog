`timescale 1ns / 1ps
module verify_tests_tb;
    reg clk; always #10 clk = ~clk;
    reg [3:0] KEY; reg [9:0] SW; wire [9:0] LEDR; wire [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;
    SingleCore_FPGA_RV32I uut(.FPGA_CLK(clk),.KEY(KEY),.SW(SW),.LEDR(LEDR),.HEX0(HEX0),.HEX1(HEX1),.HEX2(HEX2),.HEX3(HEX3),.HEX4(HEX4),.HEX5(HEX5));
    task step; begin KEY[1]=0; #40; KEY[1]=1; #40; end endtask
    integer i;
    initial begin
        clk=0; KEY=4'hF; SW=10'd0;
        KEY[0]=0; #50; KEY[0]=1; #50;
        $display("=== TEST 1: Register Viewer Test ===");
        $display("Step | PC  | Inst       | Result     | rs1        | rd1_after");
        for (i=0; i<32; i=i+1) begin
            $display("  %2d | %h | %h | %h | %h | x%0d=%h",
                i, uut.u_core.pc_out, uut.u_core.imem_inst,
                uut.u_core.reg_write_data, uut.u_core.rd1,
                i+1, uut.u_core.u_regfile.registers[i+1]);
            step();
        end
        $display("Final reg dump (x0..x31):");
        for (i=0; i<32; i=i+1)
            $display("  x%0d = %h", i, uut.u_core.u_regfile.registers[i]);
        $display("LEDR[1] (halt)=%b", LEDR[1]);
        $finish;
    end
endmodule
