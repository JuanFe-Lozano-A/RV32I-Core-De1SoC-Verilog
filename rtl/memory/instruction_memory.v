`timescale 1ns / 1ps

module instruction_memory (
    input wire [31:0] addr,
    output wire [31:0] inst
);

    reg [31:0] rom [0:63];
    integer i;

    initial begin
        // Initialize memory to 0 to prevent X states in simulation
        for (i = 0; i < 64; i = i + 1) begin
            rom[i] = 32'h00000000;
        end
        
        // Load external hex file automatically during compilation and simulation
        $readmemh("program.hex", rom);
        
        // Trap handler at 0xFC (index 63): JAL x0, 0 → infinite loop
        // This is AFTER $readmemh so it cannot be overwritten by program.hex
        rom[63] = 32'h0000006F;
    end

    // Instruction fetch, dividing PC by 4
    assign inst = rom[addr[31:2]];

endmodule
