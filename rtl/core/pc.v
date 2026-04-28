`timescale 1ns / 1ps

module pc (
    input wire clk,
    input wire reset_n,
    input wire step,
    input wire [31:0] pc_in,
    output reg [31:0] pc_out,
    
    // History Buffer Interface
    input wire restore_en,
    input wire [31:0] restore_pc
);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pc_out <= 32'b0;
        end else if (restore_en) begin
            pc_out <= restore_pc;
        end else if (step) begin
            pc_out <= pc_in;
        end
    end

endmodule
