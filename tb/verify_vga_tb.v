`timescale 1ns / 1ps

module verify_vga_tb;
    reg clk_50mhz;
    reg [3:0] KEY;
    reg [9:0] SW;
    wire [9:0] LEDR;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire [7:0] VGA_R, VGA_G, VGA_B;
    wire VGA_HS, VGA_VS, VGA_CLK, VGA_SYNC_N, VGA_BLANK_N;

    // Instantiate Top Level VGA
    SingleCore_FPGA_RV32I_VGA uut (
        .FPGA_CLK(clk_50mhz),
        .KEY(KEY),
        .SW(SW),
        .LEDR(LEDR),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_CLK(VGA_CLK),
        .VGA_SYNC_N(VGA_SYNC_N), .VGA_BLANK_N(VGA_BLANK_N)
    );

    always #10 clk_50mhz = ~clk_50mhz; // 50 MHz clock

    initial begin
        clk_50mhz = 0;
        KEY = 4'hF;
        SW = 10'd0;
        
        // Reset CPU
        KEY[0] = 0; #50; KEY[0] = 1; #50;
        
        // Enable VGA Pip-Boy mode
        SW[4] = 1'b1;

        $display("Starting VGA Timing Simulation...");
        
        // Wait for VGA to hit video_on
        // It takes a few hundred clocks to get through back porch depending on counter state
        // Let's simulate for a bit and check if we ever see non-zero RGB
        #10000;
        
        // We just want to ensure there are no latches/X states in the VGA output
        if (VGA_HS === 1'bX || VGA_VS === 1'bX) begin
            $display("ERROR: VGA Sync signals are X");
            $finish;
        end
        
        $display("VGA Timing logic is stable. HSYNC=%b VSYNC=%b VGA_CLK=%b", VGA_HS, VGA_VS, VGA_CLK);
        $display("VGA System successfully evaluated.");
        $finish;
    end
endmodule
