`timescale 1ns / 1ps

module history_buffer #(
    parameter DEPTH = 64
)(
    input wire clk,
    input wire reset_n,
    input wire push,
    input wire pop,
    input wire [2079:0] state_in,
    output reg [2079:0] state_out,
    output wire empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Split into TWO separate BRAMs to stay within M10K width inference limits.
    // bram_regs: PC (32) + Register File x0-x31 (1024)
    // bram_mem:  Data Memory snapshot
    reg [1055:0] bram_regs [0:DEPTH-1];
    reg [1023:0] bram_mem  [0:DEPTH-1];

    reg [ADDR_WIDTH-1:0] sp;
    assign empty = (sp == {ADDR_WIDTH{1'b0}});

    // Single always block — state_out must have exactly ONE driver.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sp        <= {ADDR_WIDTH{1'b0}};
            state_out <= 2080'b0;
        end else begin
            // BRAM write
            if (push) begin
                bram_regs[sp] <= state_in[2079:1024];
                bram_mem[sp]  <= state_in[1023:0];
            end
            // BRAM read (registered output for M10K inference)
            if (pop && !empty) begin
                state_out[2079:1024] <= bram_regs[sp - 1'b1];
                state_out[1023:0]    <= bram_mem[sp - 1'b1];
            end
            // Stack pointer update
            if      (push && sp != (DEPTH-1)) sp <= sp + 1'b1;
            else if (pop  && !empty)          sp <= sp - 1'b1;
        end
    end

endmodule
