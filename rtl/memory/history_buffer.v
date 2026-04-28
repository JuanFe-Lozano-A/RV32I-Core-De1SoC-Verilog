`timescale 1ns / 1ps

module history_buffer (
    input wire clk,
    input wire reset_n,
    input wire push,
    input wire pop,
    input wire [1055:0] state_in,
    output reg [1055:0] state_out,
    output wire empty
);

    // 64 deep BRAM, 1056 bits wide (32-bit PC + 1024-bit Register File)
    // Synthesizes perfectly to Altera/Intel M10K blocks if inferred synchronously
    reg [1055:0] bram [0:63];
    
    reg [5:0] sp; // Stack Pointer

    assign empty = (sp == 6'd0);

    // BRAM Write & Read (Synchronous, no async reset to guarantee inference)
    always @(posedge clk) begin
        if (push) begin
            bram[sp] <= state_in;
        end
        if (pop && !empty) begin
            state_out <= bram[sp - 1];
        end
    end

    // Stack pointer logic (with async reset)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sp <= 6'd0;
        end else begin
            if (push && sp != 6'd63) begin
                sp <= sp + 1;
            end else if (pop && !empty) begin
                sp <= sp - 1;
            end
        end
    end

endmodule
