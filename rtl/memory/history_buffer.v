`timescale 1ns / 1ps

module history_buffer (
    input wire clk,
    input wire reset_n,
    input wire push,
    input wire pop,
    input wire [2079:0] state_in,
    output reg [2079:0] state_out,
    output wire empty
);

    // Split into TWO separate BRAMs to stay within M10K width inference limits.
    // A single 2080-bit wide array falls back to ~133,120 flip-flops in logic
    // fabric and causes 15+ minute Quartus compile times.
    //
    // bram_regs: 64 x 1056 bits — PC (32) + Register File x0-x31 (1024)
    // bram_mem:  64 x 1024 bits — Data Memory snapshot
    reg [1055:0] bram_regs [0:63];
    reg [1023:0] bram_mem  [0:63];

    reg [5:0] sp;
    assign empty = (sp == 6'd0);

    // Single always block — state_out must have exactly ONE driver.
    // Quartus error 10028 fires when two always blocks both assign state_out.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sp        <= 6'd0;
            state_out <= 2080'b0;
        end else begin
            // BRAM write
            if (push) begin
                bram_regs[sp] <= state_in[2079:1024];
                bram_mem[sp]  <= state_in[1023:0];
            end
            // BRAM read (registered output for M10K inference)
            if (pop && !empty) begin
                state_out[2079:1024] <= bram_regs[sp - 1];
                state_out[1023:0]    <= bram_mem[sp - 1];
            end
            // Stack pointer update
            if      (push && sp != 6'd63) sp <= sp + 1;
            else if (pop  && !empty)      sp <= sp - 1;
        end
    end

endmodule
