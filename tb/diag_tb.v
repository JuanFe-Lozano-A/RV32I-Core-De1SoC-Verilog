`timescale 1ns / 1ps
module diag_tb;
    reg FPGA_CLK;
    reg [3:0] KEY;
    reg [9:0] SW;
    wire [9:0] LEDR;
    wire [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;

    SingleCore_FPGA_RV32I uut(.FPGA_CLK(FPGA_CLK),.KEY(KEY),.SW(SW),.LEDR(LEDR),
        .HEX0(HEX0),.HEX1(HEX1),.HEX2(HEX2),.HEX3(HEX3),.HEX4(HEX4),.HEX5(HEX5));

    always #10 FPGA_CLK = ~FPGA_CLK;

    task fwd;
        begin
            KEY[1]=0; #40; KEY[1]=1; #40;
        end
    endtask

    task bwd;
        begin
            KEY[2]=0; #40; KEY[2]=1; #80;
        end
    endtask

    integer i;
    initial begin
        FPGA_CLK=0; KEY=4'b1111; SW=10'd0;
        KEY[0]=0; #50; KEY[0]=1; #50;
        $display("After reset: PC=%0d", uut.u_core.pc_out);

        for(i=0;i<10;i=i+1) begin
            fwd();
            $display("Step %0d: PC=%0d  rd1=%0d rd2=%0d", i+1, uut.u_core.pc_out,
                uut.u_core.rd1, uut.u_core.rd2);
        end

        $display("Expected PC=40 got PC=%0d", uut.u_core.pc_out);

        $display("--- Backward x5 ---");
        for(i=0;i<5;i=i+1) begin
            bwd();
            $display("Bwd %0d: PC=%0d", i+1, uut.u_core.pc_out);
        end
        $display("Expected PC=20 got PC=%0d", uut.u_core.pc_out);
        $finish;
    end
endmodule
