`timescale 1ns / 1ps

module text_engine (
    input  wire        clk,
    input  wire        video_on,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        sw_4_enable,  // 0 = blank, 1 = Pip-Boy green
    
    // CPU State
    input  wire [31:0]   pc_out,
    input  wire [31:0]   imem_inst,
    input  wire [1023:0] monitor_regfile_state,
    input  wire [31:0]   monitor_rd1,
    input  wire [31:0]   monitor_rd2,
    input  wire [31:0]   monitor_result,
    input  wire          monitor_rs1_valid,
    input  wire          monitor_rs2_valid,
    input  wire          monitor_result_valid,
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
                    7'd0: char_code = 7'h3D; // '='
                    7'd1: char_code = 7'h3D; // '='
                    7'd2: char_code = 7'h3D; // '='
                    7'd3: char_code = 7'h20; // ' '
                    7'd4: char_code = 7'h52; // 'R'
                    7'd5: char_code = 7'h56; // 'V'
                    7'd6: char_code = 7'h33; // '3'
                    7'd7: char_code = 7'h32; // '2'
                    7'd8: char_code = 7'h49; // 'I'
                    7'd9: char_code = 7'h20; // ' '
                    7'd10: char_code = 7'h46; // 'F'
                    7'd11: char_code = 7'h50; // 'P'
                    7'd12: char_code = 7'h47; // 'G'
                    7'd13: char_code = 7'h41; // 'A'
                    7'd14: char_code = 7'h20; // ' '
                    7'd15: char_code = 7'h43; // 'C'
                    7'd16: char_code = 7'h50; // 'P'
                    7'd17: char_code = 7'h55; // 'U'
                    7'd18: char_code = 7'h20; // ' '
                    7'd19: char_code = 7'h4D; // 'M'
                    7'd20: char_code = 7'h4F; // 'O'
                    7'd21: char_code = 7'h4E; // 'N'
                    7'd22: char_code = 7'h49; // 'I'
                    7'd23: char_code = 7'h54; // 'T'
                    7'd24: char_code = 7'h4F; // 'O'
                    7'd25: char_code = 7'h52; // 'R'
                    7'd26: char_code = 7'h20; // ' '
                    7'd27: char_code = 7'h3D; // '='
                    7'd28: char_code = 7'h3D; // '='
                    7'd29: char_code = 7'h3D; // '='
                endcase
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
                    if (char_x == 50 + 0) char_code = 7'h54;
                    if (char_x == 50 + 1) char_code = 7'h52;
                    if (char_x == 50 + 2) char_code = 7'h41;
                    if (char_x == 50 + 3) char_code = 7'h50;
                    if (char_x == 50 + 4) char_code = 7'h20;
                    if (char_x == 50 + 5) char_code = 7'h45;
                    if (char_x == 50 + 6) char_code = 7'h30;
                    if (char_x == 50 + 7) char_code = 7'h30;
                    if (char_x == 50 + 8) char_code = 7'h30;
                    if (char_x == 50 + 9) char_code = 7'h30;
                    if (char_x == 60) char_code = hex2ascii(mcause);
                end
                else if (is_last_inst) begin
                    if (char_x == 50 + 0) char_code = 7'h48;
                    if (char_x == 50 + 1) char_code = 7'h41;
                    if (char_x == 50 + 2) char_code = 7'h4C;
                    if (char_x == 50 + 3) char_code = 7'h54;
                    if (char_x == 50 + 4) char_code = 7'h45;
                    if (char_x == 50 + 5) char_code = 7'h44;
                    if (char_x == 50 + 6) char_code = 7'h20;
                    if (char_x == 50 + 7) char_code = 7'h20;
                    if (char_x == 50 + 8) char_code = 7'h20;
                    if (char_x == 50 + 9) char_code = 7'h20;
                    if (char_x == 50 + 10) char_code = 7'h20;
                    if (char_x == 50 + 11) char_code = 7'h20;
                    if (char_x == 50 + 12) char_code = 7'h20;
                    if (char_x == 50 + 13) char_code = 7'h20;
                    if (char_x == 50 + 14) char_code = 7'h20;
                end
                else if (is_first_inst) begin
                    if (char_x == 50 + 0) char_code = 7'h46;
                    if (char_x == 50 + 1) char_code = 7'h49;
                    if (char_x == 50 + 2) char_code = 7'h52;
                    if (char_x == 50 + 3) char_code = 7'h53;
                    if (char_x == 50 + 4) char_code = 7'h54;
                    if (char_x == 50 + 5) char_code = 7'h20;
                    if (char_x == 50 + 6) char_code = 7'h49;
                    if (char_x == 50 + 7) char_code = 7'h4E;
                    if (char_x == 50 + 8) char_code = 7'h53;
                    if (char_x == 50 + 9) char_code = 7'h54;
                    if (char_x == 50 + 10) char_code = 7'h20;
                    if (char_x == 50 + 11) char_code = 7'h20;
                    if (char_x == 50 + 12) char_code = 7'h20;
                    if (char_x == 50 + 13) char_code = 7'h20;
                    if (char_x == 50 + 14) char_code = 7'h20;
                end
                else begin
                    if (char_x == 50 + 0) char_code = 7'h52;
                    if (char_x == 50 + 1) char_code = 7'h55;
                    if (char_x == 50 + 2) char_code = 7'h4E;
                    if (char_x == 50 + 3) char_code = 7'h4E;
                    if (char_x == 50 + 4) char_code = 7'h49;
                    if (char_x == 50 + 5) char_code = 7'h4E;
                    if (char_x == 50 + 6) char_code = 7'h47;
                    if (char_x == 50 + 7) char_code = 7'h20;
                    if (char_x == 50 + 8) char_code = 7'h20;
                    if (char_x == 50 + 9) char_code = 7'h20;
                    if (char_x == 50 + 10) char_code = 7'h20;
                    if (char_x == 50 + 11) char_code = 7'h20;
                    if (char_x == 50 + 12) char_code = 7'h20;
                    if (char_x == 50 + 13) char_code = 7'h20;
                    if (char_x == 50 + 14) char_code = 7'h20;
                end
            end
        end
        else if (char_y == 6) begin
            // ALU Res: xxxxxxxx    RS1: xxxxxxxx    RS2: xxxxxxxx
            if (char_x >= 5 && char_x < 14) begin
                case(char_x - 5)
                    0: char_code = 7'h41; // A
                    1: char_code = 7'h4C; // L
                    2: char_code = 7'h55; // U
                    3: char_code = 7'h20; //  
                    4: char_code = 7'h52; // R
                    5: char_code = 7'h65; // e
                    6: char_code = 7'h73; // s
                    7: char_code = 7'h3A; // :
                    8: char_code = 7'h20; //  
                endcase
            end
            else if (char_x >= 14 && char_x < 22) begin
                if (monitor_result_valid) begin
                    case(char_x - 14)
                        0: char_code = hex2ascii(monitor_result[31:28]);
                        1: char_code = hex2ascii(monitor_result[27:24]);
                        2: char_code = hex2ascii(monitor_result[23:20]);
                        3: char_code = hex2ascii(monitor_result[19:16]);
                        4: char_code = hex2ascii(monitor_result[15:12]);
                        5: char_code = hex2ascii(monitor_result[11:8]);
                        6: char_code = hex2ascii(monitor_result[7:4]);
                        7: char_code = hex2ascii(monitor_result[3:0]);
                    endcase
                end else begin
                    case(char_x - 14)
                        0: char_code = 7'h20; //  
                        1: char_code = 7'h20; //  
                        2: char_code = 7'h4F; // O
                        3: char_code = 7'h46; // F
                        4: char_code = 7'h46; // F
                        5: char_code = 7'h20; //  
                        6: char_code = 7'h20; //  
                        7: char_code = 7'h20; //  
                    endcase
                end
            end
            
            // RS1: xxxxxxxx
            else if (char_x >= 26 && char_x < 31) begin
                case(char_x - 26)
                    0: char_code = 7'h52; // R
                    1: char_code = 7'h53; // S
                    2: char_code = 7'h31; // 1
                    3: char_code = 7'h3A; // :
                    4: char_code = 7'h20; //  
                endcase
            end
            else if (char_x >= 31 && char_x < 39) begin
                if (monitor_rs1_valid) begin
                    case(char_x - 31)
                        0: char_code = hex2ascii(monitor_rd1[31:28]);
                        1: char_code = hex2ascii(monitor_rd1[27:24]);
                        2: char_code = hex2ascii(monitor_rd1[23:20]);
                        3: char_code = hex2ascii(monitor_rd1[19:16]);
                        4: char_code = hex2ascii(monitor_rd1[15:12]);
                        5: char_code = hex2ascii(monitor_rd1[11:8]);
                        6: char_code = hex2ascii(monitor_rd1[7:4]);
                        7: char_code = hex2ascii(monitor_rd1[3:0]);
                    endcase
                end else begin
                    case(char_x - 31)
                        0: char_code = 7'h20; //  
                        1: char_code = 7'h20; //  
                        2: char_code = 7'h4F; // O
                        3: char_code = 7'h46; // F
                        4: char_code = 7'h46; // F
                        5: char_code = 7'h20; //  
                        6: char_code = 7'h20; //  
                        7: char_code = 7'h20; //  
                    endcase
                end
            end

            // RS2: xxxxxxxx
            else if (char_x >= 43 && char_x < 48) begin
                case(char_x - 43)
                    0: char_code = 7'h52; // R
                    1: char_code = 7'h53; // S
                    2: char_code = 7'h32; // 2
                    3: char_code = 7'h3A; // :
                    4: char_code = 7'h20; //  
                endcase
            end
            else if (char_x >= 48 && char_x < 56) begin
                if (monitor_rs2_valid) begin
                    case(char_x - 48)
                        0: char_code = hex2ascii(monitor_rd2[31:28]);
                        1: char_code = hex2ascii(monitor_rd2[27:24]);
                        2: char_code = hex2ascii(monitor_rd2[23:20]);
                        3: char_code = hex2ascii(monitor_rd2[19:16]);
                        4: char_code = hex2ascii(monitor_rd2[15:12]);
                        5: char_code = hex2ascii(monitor_rd2[11:8]);
                        6: char_code = hex2ascii(monitor_rd2[7:4]);
                        7: char_code = hex2ascii(monitor_rd2[3:0]);
                    endcase
                end else begin
                    case(char_x - 48)
                        0: char_code = 7'h20; //  
                        1: char_code = 7'h20; //  
                        2: char_code = 7'h4F; // O
                        3: char_code = 7'h46; // F
                        4: char_code = 7'h46; // F
                        5: char_code = 7'h20; //  
                        6: char_code = 7'h20; //  
                        7: char_code = 7'h20; //  
                    endcase
                end
            end
        end
        else if (char_y == 9) begin
            // x00
            if (char_x >= 5 && char_x < 18) begin
                case(char_x - 5)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h30;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[0][31:28]);
                    6: char_code = hex2ascii(reg_val[0][27:24]);
                    7: char_code = hex2ascii(reg_val[0][23:20]);
                    8: char_code = hex2ascii(reg_val[0][19:16]);
                    9: char_code = hex2ascii(reg_val[0][15:12]);
                   10: char_code = hex2ascii(reg_val[0][11:8]);
                   11: char_code = hex2ascii(reg_val[0][7:4]);
                   12: char_code = hex2ascii(reg_val[0][3:0]);
                endcase
            end
            // x08
            if (char_x >= 25 && char_x < 38) begin
                case(char_x - 25)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h38;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[8][31:28]);
                    6: char_code = hex2ascii(reg_val[8][27:24]);
                    7: char_code = hex2ascii(reg_val[8][23:20]);
                    8: char_code = hex2ascii(reg_val[8][19:16]);
                    9: char_code = hex2ascii(reg_val[8][15:12]);
                   10: char_code = hex2ascii(reg_val[8][11:8]);
                   11: char_code = hex2ascii(reg_val[8][7:4]);
                   12: char_code = hex2ascii(reg_val[8][3:0]);
                endcase
            end
            // x16
            if (char_x >= 45 && char_x < 58) begin
                case(char_x - 45)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h36;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[16][31:28]);
                    6: char_code = hex2ascii(reg_val[16][27:24]);
                    7: char_code = hex2ascii(reg_val[16][23:20]);
                    8: char_code = hex2ascii(reg_val[16][19:16]);
                    9: char_code = hex2ascii(reg_val[16][15:12]);
                   10: char_code = hex2ascii(reg_val[16][11:8]);
                   11: char_code = hex2ascii(reg_val[16][7:4]);
                   12: char_code = hex2ascii(reg_val[16][3:0]);
                endcase
            end
            // x24
            if (char_x >= 65 && char_x < 78) begin
                case(char_x - 65)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h34;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[24][31:28]);
                    6: char_code = hex2ascii(reg_val[24][27:24]);
                    7: char_code = hex2ascii(reg_val[24][23:20]);
                    8: char_code = hex2ascii(reg_val[24][19:16]);
                    9: char_code = hex2ascii(reg_val[24][15:12]);
                   10: char_code = hex2ascii(reg_val[24][11:8]);
                   11: char_code = hex2ascii(reg_val[24][7:4]);
                   12: char_code = hex2ascii(reg_val[24][3:0]);
                endcase
            end
        end
        else if (char_y == 11) begin
            // x01
            if (char_x >= 5 && char_x < 18) begin
                case(char_x - 5)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h31;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[1][31:28]);
                    6: char_code = hex2ascii(reg_val[1][27:24]);
                    7: char_code = hex2ascii(reg_val[1][23:20]);
                    8: char_code = hex2ascii(reg_val[1][19:16]);
                    9: char_code = hex2ascii(reg_val[1][15:12]);
                   10: char_code = hex2ascii(reg_val[1][11:8]);
                   11: char_code = hex2ascii(reg_val[1][7:4]);
                   12: char_code = hex2ascii(reg_val[1][3:0]);
                endcase
            end
            // x09
            if (char_x >= 25 && char_x < 38) begin
                case(char_x - 25)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h39;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[9][31:28]);
                    6: char_code = hex2ascii(reg_val[9][27:24]);
                    7: char_code = hex2ascii(reg_val[9][23:20]);
                    8: char_code = hex2ascii(reg_val[9][19:16]);
                    9: char_code = hex2ascii(reg_val[9][15:12]);
                   10: char_code = hex2ascii(reg_val[9][11:8]);
                   11: char_code = hex2ascii(reg_val[9][7:4]);
                   12: char_code = hex2ascii(reg_val[9][3:0]);
                endcase
            end
            // x17
            if (char_x >= 45 && char_x < 58) begin
                case(char_x - 45)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h37;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[17][31:28]);
                    6: char_code = hex2ascii(reg_val[17][27:24]);
                    7: char_code = hex2ascii(reg_val[17][23:20]);
                    8: char_code = hex2ascii(reg_val[17][19:16]);
                    9: char_code = hex2ascii(reg_val[17][15:12]);
                   10: char_code = hex2ascii(reg_val[17][11:8]);
                   11: char_code = hex2ascii(reg_val[17][7:4]);
                   12: char_code = hex2ascii(reg_val[17][3:0]);
                endcase
            end
            // x25
            if (char_x >= 65 && char_x < 78) begin
                case(char_x - 65)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h35;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[25][31:28]);
                    6: char_code = hex2ascii(reg_val[25][27:24]);
                    7: char_code = hex2ascii(reg_val[25][23:20]);
                    8: char_code = hex2ascii(reg_val[25][19:16]);
                    9: char_code = hex2ascii(reg_val[25][15:12]);
                   10: char_code = hex2ascii(reg_val[25][11:8]);
                   11: char_code = hex2ascii(reg_val[25][7:4]);
                   12: char_code = hex2ascii(reg_val[25][3:0]);
                endcase
            end
        end
        else if (char_y == 13) begin
            // x02
            if (char_x >= 5 && char_x < 18) begin
                case(char_x - 5)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h32;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[2][31:28]);
                    6: char_code = hex2ascii(reg_val[2][27:24]);
                    7: char_code = hex2ascii(reg_val[2][23:20]);
                    8: char_code = hex2ascii(reg_val[2][19:16]);
                    9: char_code = hex2ascii(reg_val[2][15:12]);
                   10: char_code = hex2ascii(reg_val[2][11:8]);
                   11: char_code = hex2ascii(reg_val[2][7:4]);
                   12: char_code = hex2ascii(reg_val[2][3:0]);
                endcase
            end
            // x10
            if (char_x >= 25 && char_x < 38) begin
                case(char_x - 25)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h30;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[10][31:28]);
                    6: char_code = hex2ascii(reg_val[10][27:24]);
                    7: char_code = hex2ascii(reg_val[10][23:20]);
                    8: char_code = hex2ascii(reg_val[10][19:16]);
                    9: char_code = hex2ascii(reg_val[10][15:12]);
                   10: char_code = hex2ascii(reg_val[10][11:8]);
                   11: char_code = hex2ascii(reg_val[10][7:4]);
                   12: char_code = hex2ascii(reg_val[10][3:0]);
                endcase
            end
            // x18
            if (char_x >= 45 && char_x < 58) begin
                case(char_x - 45)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h38;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[18][31:28]);
                    6: char_code = hex2ascii(reg_val[18][27:24]);
                    7: char_code = hex2ascii(reg_val[18][23:20]);
                    8: char_code = hex2ascii(reg_val[18][19:16]);
                    9: char_code = hex2ascii(reg_val[18][15:12]);
                   10: char_code = hex2ascii(reg_val[18][11:8]);
                   11: char_code = hex2ascii(reg_val[18][7:4]);
                   12: char_code = hex2ascii(reg_val[18][3:0]);
                endcase
            end
            // x26
            if (char_x >= 65 && char_x < 78) begin
                case(char_x - 65)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h36;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[26][31:28]);
                    6: char_code = hex2ascii(reg_val[26][27:24]);
                    7: char_code = hex2ascii(reg_val[26][23:20]);
                    8: char_code = hex2ascii(reg_val[26][19:16]);
                    9: char_code = hex2ascii(reg_val[26][15:12]);
                   10: char_code = hex2ascii(reg_val[26][11:8]);
                   11: char_code = hex2ascii(reg_val[26][7:4]);
                   12: char_code = hex2ascii(reg_val[26][3:0]);
                endcase
            end
        end
        else if (char_y == 15) begin
            // x03
            if (char_x >= 5 && char_x < 18) begin
                case(char_x - 5)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h33;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[3][31:28]);
                    6: char_code = hex2ascii(reg_val[3][27:24]);
                    7: char_code = hex2ascii(reg_val[3][23:20]);
                    8: char_code = hex2ascii(reg_val[3][19:16]);
                    9: char_code = hex2ascii(reg_val[3][15:12]);
                   10: char_code = hex2ascii(reg_val[3][11:8]);
                   11: char_code = hex2ascii(reg_val[3][7:4]);
                   12: char_code = hex2ascii(reg_val[3][3:0]);
                endcase
            end
            // x11
            if (char_x >= 25 && char_x < 38) begin
                case(char_x - 25)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h31;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[11][31:28]);
                    6: char_code = hex2ascii(reg_val[11][27:24]);
                    7: char_code = hex2ascii(reg_val[11][23:20]);
                    8: char_code = hex2ascii(reg_val[11][19:16]);
                    9: char_code = hex2ascii(reg_val[11][15:12]);
                   10: char_code = hex2ascii(reg_val[11][11:8]);
                   11: char_code = hex2ascii(reg_val[11][7:4]);
                   12: char_code = hex2ascii(reg_val[11][3:0]);
                endcase
            end
            // x19
            if (char_x >= 45 && char_x < 58) begin
                case(char_x - 45)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h39;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[19][31:28]);
                    6: char_code = hex2ascii(reg_val[19][27:24]);
                    7: char_code = hex2ascii(reg_val[19][23:20]);
                    8: char_code = hex2ascii(reg_val[19][19:16]);
                    9: char_code = hex2ascii(reg_val[19][15:12]);
                   10: char_code = hex2ascii(reg_val[19][11:8]);
                   11: char_code = hex2ascii(reg_val[19][7:4]);
                   12: char_code = hex2ascii(reg_val[19][3:0]);
                endcase
            end
            // x27
            if (char_x >= 65 && char_x < 78) begin
                case(char_x - 65)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h37;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[27][31:28]);
                    6: char_code = hex2ascii(reg_val[27][27:24]);
                    7: char_code = hex2ascii(reg_val[27][23:20]);
                    8: char_code = hex2ascii(reg_val[27][19:16]);
                    9: char_code = hex2ascii(reg_val[27][15:12]);
                   10: char_code = hex2ascii(reg_val[27][11:8]);
                   11: char_code = hex2ascii(reg_val[27][7:4]);
                   12: char_code = hex2ascii(reg_val[27][3:0]);
                endcase
            end
        end
        else if (char_y == 17) begin
            // x04
            if (char_x >= 5 && char_x < 18) begin
                case(char_x - 5)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h34;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[4][31:28]);
                    6: char_code = hex2ascii(reg_val[4][27:24]);
                    7: char_code = hex2ascii(reg_val[4][23:20]);
                    8: char_code = hex2ascii(reg_val[4][19:16]);
                    9: char_code = hex2ascii(reg_val[4][15:12]);
                   10: char_code = hex2ascii(reg_val[4][11:8]);
                   11: char_code = hex2ascii(reg_val[4][7:4]);
                   12: char_code = hex2ascii(reg_val[4][3:0]);
                endcase
            end
            // x12
            if (char_x >= 25 && char_x < 38) begin
                case(char_x - 25)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h32;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[12][31:28]);
                    6: char_code = hex2ascii(reg_val[12][27:24]);
                    7: char_code = hex2ascii(reg_val[12][23:20]);
                    8: char_code = hex2ascii(reg_val[12][19:16]);
                    9: char_code = hex2ascii(reg_val[12][15:12]);
                   10: char_code = hex2ascii(reg_val[12][11:8]);
                   11: char_code = hex2ascii(reg_val[12][7:4]);
                   12: char_code = hex2ascii(reg_val[12][3:0]);
                endcase
            end
            // x20
            if (char_x >= 45 && char_x < 58) begin
                case(char_x - 45)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h30;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[20][31:28]);
                    6: char_code = hex2ascii(reg_val[20][27:24]);
                    7: char_code = hex2ascii(reg_val[20][23:20]);
                    8: char_code = hex2ascii(reg_val[20][19:16]);
                    9: char_code = hex2ascii(reg_val[20][15:12]);
                   10: char_code = hex2ascii(reg_val[20][11:8]);
                   11: char_code = hex2ascii(reg_val[20][7:4]);
                   12: char_code = hex2ascii(reg_val[20][3:0]);
                endcase
            end
            // x28
            if (char_x >= 65 && char_x < 78) begin
                case(char_x - 65)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h38;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[28][31:28]);
                    6: char_code = hex2ascii(reg_val[28][27:24]);
                    7: char_code = hex2ascii(reg_val[28][23:20]);
                    8: char_code = hex2ascii(reg_val[28][19:16]);
                    9: char_code = hex2ascii(reg_val[28][15:12]);
                   10: char_code = hex2ascii(reg_val[28][11:8]);
                   11: char_code = hex2ascii(reg_val[28][7:4]);
                   12: char_code = hex2ascii(reg_val[28][3:0]);
                endcase
            end
        end
        else if (char_y == 19) begin
            // x05
            if (char_x >= 5 && char_x < 18) begin
                case(char_x - 5)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h35;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[5][31:28]);
                    6: char_code = hex2ascii(reg_val[5][27:24]);
                    7: char_code = hex2ascii(reg_val[5][23:20]);
                    8: char_code = hex2ascii(reg_val[5][19:16]);
                    9: char_code = hex2ascii(reg_val[5][15:12]);
                   10: char_code = hex2ascii(reg_val[5][11:8]);
                   11: char_code = hex2ascii(reg_val[5][7:4]);
                   12: char_code = hex2ascii(reg_val[5][3:0]);
                endcase
            end
            // x13
            if (char_x >= 25 && char_x < 38) begin
                case(char_x - 25)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h33;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[13][31:28]);
                    6: char_code = hex2ascii(reg_val[13][27:24]);
                    7: char_code = hex2ascii(reg_val[13][23:20]);
                    8: char_code = hex2ascii(reg_val[13][19:16]);
                    9: char_code = hex2ascii(reg_val[13][15:12]);
                   10: char_code = hex2ascii(reg_val[13][11:8]);
                   11: char_code = hex2ascii(reg_val[13][7:4]);
                   12: char_code = hex2ascii(reg_val[13][3:0]);
                endcase
            end
            // x21
            if (char_x >= 45 && char_x < 58) begin
                case(char_x - 45)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h31;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[21][31:28]);
                    6: char_code = hex2ascii(reg_val[21][27:24]);
                    7: char_code = hex2ascii(reg_val[21][23:20]);
                    8: char_code = hex2ascii(reg_val[21][19:16]);
                    9: char_code = hex2ascii(reg_val[21][15:12]);
                   10: char_code = hex2ascii(reg_val[21][11:8]);
                   11: char_code = hex2ascii(reg_val[21][7:4]);
                   12: char_code = hex2ascii(reg_val[21][3:0]);
                endcase
            end
            // x29
            if (char_x >= 65 && char_x < 78) begin
                case(char_x - 65)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h39;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[29][31:28]);
                    6: char_code = hex2ascii(reg_val[29][27:24]);
                    7: char_code = hex2ascii(reg_val[29][23:20]);
                    8: char_code = hex2ascii(reg_val[29][19:16]);
                    9: char_code = hex2ascii(reg_val[29][15:12]);
                   10: char_code = hex2ascii(reg_val[29][11:8]);
                   11: char_code = hex2ascii(reg_val[29][7:4]);
                   12: char_code = hex2ascii(reg_val[29][3:0]);
                endcase
            end
        end
        else if (char_y == 21) begin
            // x06
            if (char_x >= 5 && char_x < 18) begin
                case(char_x - 5)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h36;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[6][31:28]);
                    6: char_code = hex2ascii(reg_val[6][27:24]);
                    7: char_code = hex2ascii(reg_val[6][23:20]);
                    8: char_code = hex2ascii(reg_val[6][19:16]);
                    9: char_code = hex2ascii(reg_val[6][15:12]);
                   10: char_code = hex2ascii(reg_val[6][11:8]);
                   11: char_code = hex2ascii(reg_val[6][7:4]);
                   12: char_code = hex2ascii(reg_val[6][3:0]);
                endcase
            end
            // x14
            if (char_x >= 25 && char_x < 38) begin
                case(char_x - 25)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h34;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[14][31:28]);
                    6: char_code = hex2ascii(reg_val[14][27:24]);
                    7: char_code = hex2ascii(reg_val[14][23:20]);
                    8: char_code = hex2ascii(reg_val[14][19:16]);
                    9: char_code = hex2ascii(reg_val[14][15:12]);
                   10: char_code = hex2ascii(reg_val[14][11:8]);
                   11: char_code = hex2ascii(reg_val[14][7:4]);
                   12: char_code = hex2ascii(reg_val[14][3:0]);
                endcase
            end
            // x22
            if (char_x >= 45 && char_x < 58) begin
                case(char_x - 45)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h32;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[22][31:28]);
                    6: char_code = hex2ascii(reg_val[22][27:24]);
                    7: char_code = hex2ascii(reg_val[22][23:20]);
                    8: char_code = hex2ascii(reg_val[22][19:16]);
                    9: char_code = hex2ascii(reg_val[22][15:12]);
                   10: char_code = hex2ascii(reg_val[22][11:8]);
                   11: char_code = hex2ascii(reg_val[22][7:4]);
                   12: char_code = hex2ascii(reg_val[22][3:0]);
                endcase
            end
            // x30
            if (char_x >= 65 && char_x < 78) begin
                case(char_x - 65)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h33;
                    2: char_code = 7'h30;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[30][31:28]);
                    6: char_code = hex2ascii(reg_val[30][27:24]);
                    7: char_code = hex2ascii(reg_val[30][23:20]);
                    8: char_code = hex2ascii(reg_val[30][19:16]);
                    9: char_code = hex2ascii(reg_val[30][15:12]);
                   10: char_code = hex2ascii(reg_val[30][11:8]);
                   11: char_code = hex2ascii(reg_val[30][7:4]);
                   12: char_code = hex2ascii(reg_val[30][3:0]);
                endcase
            end
        end
        else if (char_y == 23) begin
            // x07
            if (char_x >= 5 && char_x < 18) begin
                case(char_x - 5)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h30;
                    2: char_code = 7'h37;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[7][31:28]);
                    6: char_code = hex2ascii(reg_val[7][27:24]);
                    7: char_code = hex2ascii(reg_val[7][23:20]);
                    8: char_code = hex2ascii(reg_val[7][19:16]);
                    9: char_code = hex2ascii(reg_val[7][15:12]);
                   10: char_code = hex2ascii(reg_val[7][11:8]);
                   11: char_code = hex2ascii(reg_val[7][7:4]);
                   12: char_code = hex2ascii(reg_val[7][3:0]);
                endcase
            end
            // x15
            if (char_x >= 25 && char_x < 38) begin
                case(char_x - 25)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h31;
                    2: char_code = 7'h35;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[15][31:28]);
                    6: char_code = hex2ascii(reg_val[15][27:24]);
                    7: char_code = hex2ascii(reg_val[15][23:20]);
                    8: char_code = hex2ascii(reg_val[15][19:16]);
                    9: char_code = hex2ascii(reg_val[15][15:12]);
                   10: char_code = hex2ascii(reg_val[15][11:8]);
                   11: char_code = hex2ascii(reg_val[15][7:4]);
                   12: char_code = hex2ascii(reg_val[15][3:0]);
                endcase
            end
            // x23
            if (char_x >= 45 && char_x < 58) begin
                case(char_x - 45)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h32;
                    2: char_code = 7'h33;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[23][31:28]);
                    6: char_code = hex2ascii(reg_val[23][27:24]);
                    7: char_code = hex2ascii(reg_val[23][23:20]);
                    8: char_code = hex2ascii(reg_val[23][19:16]);
                    9: char_code = hex2ascii(reg_val[23][15:12]);
                   10: char_code = hex2ascii(reg_val[23][11:8]);
                   11: char_code = hex2ascii(reg_val[23][7:4]);
                   12: char_code = hex2ascii(reg_val[23][3:0]);
                endcase
            end
            // x31
            if (char_x >= 65 && char_x < 78) begin
                case(char_x - 65)
                    0: char_code = 7'h78; // 'x'
                    1: char_code = 7'h33;
                    2: char_code = 7'h31;
                    3: char_code = 7'h3A; // ':'
                    4: char_code = 7'h20; // ' '
                    5: char_code = hex2ascii(reg_val[31][31:28]);
                    6: char_code = hex2ascii(reg_val[31][27:24]);
                    7: char_code = hex2ascii(reg_val[31][23:20]);
                    8: char_code = hex2ascii(reg_val[31][19:16]);
                    9: char_code = hex2ascii(reg_val[31][15:12]);
                   10: char_code = hex2ascii(reg_val[31][11:8]);
                   11: char_code = hex2ascii(reg_val[31][7:4]);
                   12: char_code = hex2ascii(reg_val[31][3:0]);
                endcase
            end
        end
    end // always @(*)

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
    // Font data is 8 bits wide, LSB is left-most pixel for the new chunky font.
    wire pixel_active = font_data[font_col_d];

    // Pip-Boy Colors
    always @(*) begin
        if (!video_on_d || sw_4_enable == 1'b0) begin
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
