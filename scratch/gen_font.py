from PIL import Image, ImageDraw, ImageFont
import os

# We will generate a 128 character font (ASCII 0-127)
# 8 pixels wide, 16 pixels high.
# We will use the default PIL font which is a bit small, but we can scale it or draw lines if needed.
# Actually, since we want a good retro VGA font, let's just download one if possible, or hardcode a base64 of a known font.
# A standard 8x16 font file is usually 4096 bytes (256 chars * 16 bytes).
# Let's download a classic 8x16 font hex file from a known repo, or generate a basic one.
import urllib.request

url = "https://raw.githubusercontent.com/dhepper/font8x8/master/font8x8_basic.h"
# That's 8x8. We want 8x16.
# Let's use a standard 8x16 VGA font dump from a gist.
# https://raw.githubusercontent.com/Vile-H/vga-font/master/vga-rom-16.S
# Or I can just write a script that generates a very simple 5x7 font centered in 8x16.

# Let's use PIL to generate a decent looking 8x16 font.
font_data = []
try:
    font = ImageFont.truetype("lucon.ttf", 15) # Consolas or Lucida Console
except:
    font = ImageFont.load_default()

for i in range(128):
    img = Image.new('1', (8, 16), color=0)
    d = ImageDraw.Draw(img)
    # Don't draw control characters
    if i >= 32 and i < 127:
        char = chr(i)
        # Center the character
        bbox = d.textbbox((0, 0), char, font=font)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        x = (8 - w) // 2
        y = (16 - h) // 2
        d.text((x, y), char, font=font, fill=1)
    
    # Extract bytes
    char_bytes = []
    for row in range(16):
        byte_val = 0
        for col in range(8):
            pixel = img.getpixel((col, row))
            if pixel:
                byte_val |= (1 << (7 - col))
        char_bytes.append(byte_val)
    font_data.extend(char_bytes)

with open('../rtl/vga/font_rom.v', 'w') as f:
    f.write('`timescale 1ns / 1ps\n\n')
    f.write('module font_rom (\n')
    f.write('    input wire clk,\n')
    f.write('    input wire [10:0] addr,  // 128 chars * 16 rows = 2048 addresses (11 bits)\n')
    f.write('    output reg [7:0] data\n')
    f.write(');\n\n')
    f.write('    // 2048-byte ROM for 8x16 font (ASCII 0-127)\n')
    f.write('    always @(posedge clk) begin\n')
    f.write('        case(addr)\n')
    for i, byte_val in enumerate(font_data):
        if byte_val != 0:
            f.write(f'            11\'d{i}: data <= 8\'h{byte_val:02X};\n')
    f.write('            default: data <= 8\'h00;\n')
    f.write('        endcase\n')
    f.write('    end\n')
    f.write('endmodule\n')

print("font_rom.v generated successfully.")
