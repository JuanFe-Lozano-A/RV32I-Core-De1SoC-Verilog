import os

verilog_code = """`timescale 1ns / 1ps

module text_engine (
    input  wire        clk,
    input  wire        video_on,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        sw_1,  // 0 = blank, 1 = Pip-Boy green
    
    // CPU State
    input  wire [31:0]   pc_out,
    input  wire [31:0]   imem_inst,
    input  wire [1023:0] monitor_regfile_state,
    input  wire [31:0]   monitor_rd1,
    input  wire [31:0]   monitor_rd2,
    input  wire [31:0]   monitor_result,
    input  wire          trap_active,
    input  wire [3:0]    mcause,
    input  wire          is_first_inst,
    input  wire          is_last_inst,
    
    // RGB outputs
    output reg  [7:0]  red,
    output reg  [7:0]  green,
    output reg  [7:0]  blue
);

    wire [6:0] char_x = pixel_x[9:3]; // 0 to 79
    wire [4:0] char_y = pixel_y[9:4]; // 0 to 29
    wire [2:0] row_in_char = pixel_y[3:1]; // 0 to 7 (Wait, 16 pixels high! pixel_y[3:0] is 0-15)
    wire [3:0] font_row = pixel_y[3:0];
    wire [2:0] font_col = pixel_x[2:0];

    // Unpack register file
    wire [31:0] reg_val [0:31];
    genvar i;
    generate
        for(i=0; i<32; i=i+1) begin : unp
            assign reg_val[i] = monitor_regfile_state[i*32 +: 32];
        end
    endgenerate

    function [6:0] hex2ascii;
        input [3:0] hex;
        begin
            if (hex < 10) hex2ascii = 7'h30 + hex; // '0'-'9'
            else          hex2ascii = 7'h37 + hex; // 'A'-'F'
        end
    endfunction

    reg [6:0] char_code;

    // Combinational Character Map
    always @(*) begin
        char_code = 7'h20; // Default Space
        
        if (char_y == 2) begin
            // Title: "=== RV32I FPGA CPU MONITOR ===" (length 30)
            if (char_x >= 25 && char_x < 55) begin
                case (char_x - 25)
"""

title = "=== RV32I FPGA CPU MONITOR ==="
for i, c in enumerate(title):
    verilog_code += f"                    7'd{i}: char_code = 7'h{ord(c):02X}; // '{c}'\n"

verilog_code += """                endcase
            end
        end
        else if (char_y == 4) begin
            // PC: xxxxxxxx
            if (char_x >= 5 && char_x < 9) begin
                case(char_x - 5)
                    0: char_code = 7'h50; // P
                    1: char_code = 7'h43; // C
                    2: char_code = 7'h3A; // :
                    3: char_code = 7'h20; //  
                endcase
            end
            else if (char_x >= 9 && char_x < 17) begin
                case(char_x - 9)
                    0: char_code = hex2ascii(pc_out[31:28]);
                    1: char_code = hex2ascii(pc_out[27:24]);
                    2: char_code = hex2ascii(pc_out[23:20]);
                    3: char_code = hex2ascii(pc_out[19:16]);
                    4: char_code = hex2ascii(pc_out[15:12]);
                    5: char_code = hex2ascii(pc_out[11:8]);
                    6: char_code = hex2ascii(pc_out[7:4]);
                    7: char_code = hex2ascii(pc_out[3:0]);
                endcase
            end
            
            // Inst: xxxxxxxx
            else if (char_x >= 25 && char_x < 31) begin
                case(char_x - 25)
                    0: char_code = 7'h49; // I
                    1: char_code = 7'h6E; // n
                    2: char_code = 7'h73; // s
                    3: char_code = 7'h74; // t
                    4: char_code = 7'h3A; // :
                    5: char_code = 7'h20; //  
                endcase
            end
            else if (char_x >= 31 && char_x < 39) begin
                case(char_x - 31)
                    0: char_code = hex2ascii(imem_inst[31:28]);
                    1: char_code = hex2ascii(imem_inst[27:24]);
                    2: char_code = hex2ascii(imem_inst[23:20]);
                    3: char_code = hex2ascii(imem_inst[19:16]);
                    4: char_code = hex2ascii(imem_inst[15:12]);
                    5: char_code = hex2ascii(imem_inst[11:8]);
                    6: char_code = hex2ascii(imem_inst[7:4]);
                    7: char_code = hex2ascii(imem_inst[3:0]);
                endcase
            end
            
            // Status Zone
            else if (char_x >= 50 && char_x < 65) begin
                if (trap_active) begin
"""

trap_msg = "TRAP E0000"
for i, c in enumerate(trap_msg):
    verilog_code += f"                    if (char_x == 50 + {i}) char_code = 7'h{ord(c):02X};\n"

verilog_code += """                    if (char_x == 60) char_code = hex2ascii(mcause);
                end
                else if (is_last_inst) begin
"""

halt_msg = "HALTED         "
for i, c in enumerate(halt_msg):
    verilog_code += f"                    if (char_x == 50 + {i}) char_code = 7'h{ord(c):02X};\n"

verilog_code += """                end
                else if (is_first_inst) begin
"""

first_msg = "FIRST INST     "
for i, c in enumerate(first_msg):
    verilog_code += f"                    if (char_x == 50 + {i}) char_code = 7'h{ord(c):02X};\n"

verilog_code += """                end
                else begin
"""

run_msg = "RUNNING        "
for i, c in enumerate(run_msg):
    verilog_code += f"                    if (char_x == 50 + {i}) char_code = 7'h{ord(c):02X};\n"

verilog_code += """                end
            end
        end
        else if (char_y == 6) begin
            // ALU Result: xxxxxxxx
            if (char_x >= 5 && char_x < 17) begin
                case(char_x - 5)
"""
alu_label = "ALU Result: "
for i, c in enumerate(alu_label):
    verilog_code += f"                    {i}: char_code = 7'h{ord(c):02X};\n"

verilog_code += """                endcase
            end
            else if (char_x >= 17 && char_x < 25) begin
                case(char_x - 17)
                    0: char_code = hex2ascii(monitor_result[31:28]);
                    1: char_code = hex2ascii(monitor_result[27:24]);
                    2: char_code = hex2ascii(monitor_result[23:20]);
                    3: char_code = hex2ascii(monitor_result[19:16]);
                    4: char_code = hex2ascii(monitor_result[15:12]);
                    5: char_code = hex2ascii(monitor_result[11:8]);
                    6: char_code = hex2ascii(monitor_result[7:4]);
                    7: char_code = hex2ascii(monitor_result[3:0]);
                endcase
            end
        end
"""

# Registers Grid
# 32 registers. We put them in 4 columns, 8 rows.
# Col 0: x=5, Col 1: x=25, Col 2: x=45, Col 3: x=65
# Row 0: y=9, Row 1: y=11, ... Row 7: y=23
# Format: "x00: xxxxxxxx" (13 chars)

for row in range(8):
    y = 9 + row*2
    verilog_code += f"        else if (char_y == {y}) begin\n"
    for col in range(4):
        reg_idx = col * 8 + row
        x_start = 5 + col * 20
        verilog_code += f"            // x{reg_idx:02d}\n"
        verilog_code += f"            if (char_x >= {x_start} && char_x < {x_start+13}) begin\n"
        verilog_code += f"                case(char_x - {x_start})\n"
        verilog_code += f"                    0: char_code = 7'h78; // 'x'\n"
        verilog_code += f"                    1: char_code = 7'h{(ord('0') + reg_idx//10):02X};\n"
        verilog_code += f"                    2: char_code = 7'h{(ord('0') + reg_idx%10):02X};\n"
        verilog_code += f"                    3: char_code = 7'h3A; // ':'\n"
        verilog_code += f"                    4: char_code = 7'h20; // ' '\n"
        verilog_code += f"                    5: char_code = hex2ascii(reg_val[{reg_idx}][31:28]);\n"
        verilog_code += f"                    6: char_code = hex2ascii(reg_val[{reg_idx}][27:24]);\n"
        verilog_code += f"                    7: char_code = hex2ascii(reg_val[{reg_idx}][23:20]);\n"
        verilog_code += f"                    8: char_code = hex2ascii(reg_val[{reg_idx}][19:16]);\n"
        verilog_code += f"                    9: char_code = hex2ascii(reg_val[{reg_idx}][15:12]);\n"
        verilog_code += f"                   10: char_code = hex2ascii(reg_val[{reg_idx}][11:8]);\n"
        verilog_code += f"                   11: char_code = hex2ascii(reg_val[{reg_idx}][7:4]);\n"
        verilog_code += f"                   12: char_code = hex2ascii(reg_val[{reg_idx}][3:0]);\n"
        verilog_code += f"                endcase\n"
        verilog_code += f"            end\n"
    verilog_code += f"        end\n"

verilog_code += """    end // always @(*)

    // Font ROM Instantiation
    wire [10:0] rom_addr = {char_code, font_row};
    wire [7:0]  font_data;
    
    font_rom u_font (
        .clk(clk),
        .addr(rom_addr),
        .data(font_data)
    );

    // 1-cycle delay pipeline for sync signals because ROM has 1-cycle latency
    reg video_on_d;
    reg [2:0] font_col_d;
    
    always @(posedge clk) begin
        video_on_d <= video_on;
        font_col_d <= font_col;
    end

    // Pixel color extraction
    // Font data is 8 bits wide, MSB is left-most pixel.
    wire pixel_active = font_data[7 - font_col_d];

    // Pip-Boy Colors
    always @(*) begin
        if (!video_on_d || sw_1 == 1'b0) begin
            // Blank / Sync interval / Test Mode 0
            red   = 8'h00;
            green = 8'h00;
            blue  = 8'h00;
        end
        else begin
            if (pixel_active) begin
                // Foreground: Bright retro green
                red   = 8'h00;
                green = 8'hFF;
                blue  = 8'h00;
            end else begin
                // Background: Very dark green (Pip-boy style)
                red   = 8'h00;
                green = 8'h11;
                blue  = 8'h00;
            end
        end
    end

endmodule
"""

with open('../rtl/vga/text_engine.v', 'w') as f:
    f.write(verilog_code)

print("text_engine.v generated successfully.")
