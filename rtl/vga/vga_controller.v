`timescale 1ns / 1ps

module vga_controller (
    input  wire       clk_25mhz,
    input  wire       reset_n,
    output wire       hsync,
    output wire       vsync,
    output wire       video_on,
    output wire [9:0] pixel_x,
    output wire [9:0] pixel_y
);

    // VGA 640x480 @ 60Hz timing parameters
    parameter H_DISPLAY = 640;
    parameter H_FRONT   = 16;
    parameter H_SYNC    = 96;
    parameter H_BACK    = 48;
    parameter H_MAX     = H_DISPLAY + H_FRONT + H_SYNC + H_BACK - 1; // 799

    parameter V_DISPLAY = 480;
    parameter V_FRONT   = 10;
    parameter V_SYNC    = 2;
    parameter V_BACK    = 33;
    parameter V_MAX     = V_DISPLAY + V_FRONT + V_SYNC + V_BACK - 1; // 524

    reg [9:0] h_count;
    reg [9:0] v_count;

    // Horizontal & Vertical counters
    always @(posedge clk_25mhz or negedge reset_n) begin
        if (!reset_n) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else begin
            if (h_count == H_MAX) begin
                h_count <= 10'd0;
                if (v_count == V_MAX) begin
                    v_count <= 10'd0;
                end else begin
                    v_count <= v_count + 1'b1;
                end
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    // Sync pulse generation (Active Low for 640x480 standard)
    assign hsync = ~(h_count >= (H_DISPLAY + H_FRONT) && h_count < (H_DISPLAY + H_FRONT + H_SYNC));
    assign vsync = ~(v_count >= (V_DISPLAY + V_FRONT) && v_count < (V_DISPLAY + V_FRONT + V_SYNC));

    // Video On (Visible area)
    assign video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

    // Pixel coordinates
    assign pixel_x = h_count;
    assign pixel_y = v_count;

endmodule
