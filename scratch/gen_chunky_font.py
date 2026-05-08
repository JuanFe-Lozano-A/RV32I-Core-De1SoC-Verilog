import re

def generate_chunky_font(in_h, out_v):
    # Read the C header file
    with open(in_h, 'r') as f:
        content = f.read()

    # Find the array content
    match = re.search(r'char font8x8_basic\[128\]\[8\] = \{(.*?)\};', content, re.DOTALL)
    if not match:
        print("Could not find font array")
        return
        
    array_str = match.group(1)
    
    # Parse the bytes
    chars = []
    for line in array_str.split('\n'):
        if '{' in line and '}' in line:
            byte_strs = re.findall(r'0x[0-9A-Fa-f]{2}', line)
            if len(byte_strs) == 8:
                bytes_list = [int(b, 16) for b in byte_strs]
                chars.append(bytes_list)
                
    if len(chars) != 128:
        print(f"Expected 128 chars, found {len(chars)}")
        return

    # Generate 8x16 font by duplicating each row twice (chunky Pip-Boy scaling)
    with open(out_v, 'w') as f:
        f.write('`timescale 1ns / 1ps\n\n')
        f.write('module font_rom (\n')
        f.write('    input wire clk,\n')
        f.write('    input wire [10:0] addr,  // 128 chars * 16 rows = 2048 addresses (11 bits)\n')
        f.write('    output reg [7:0] data\n')
        f.write(');\n\n')
        f.write('    // 2048-byte ROM for 8x16 font (ASCII 0-127), chunky scaled from 8x8\n')
        f.write('    always @(posedge clk) begin\n')
        f.write('        case(addr)\n')
        
        addr = 0
        for char_idx in range(128):
            for row in range(8):
                byte_val = chars[char_idx][row]
                # Write it twice to make it 2x vertically thick!
                f.write(f"            11'd{addr}: data = 8'h{byte_val:02X};\n")
                addr += 1
                f.write(f"            11'd{addr}: data = 8'h{byte_val:02X};\n")
                addr += 1
                
        f.write("            default: data = 8'b0;\n")
        f.write('        endcase\n')
        f.write('    end\n')
        f.write('endmodule\n')

if __name__ == '__main__':
    in_path = r'c:\Users\juanf\Documents\Universidad\Arquitectura de Computadores\FPGA-RiscV32I\scratch\font8x8_basic.h'
    out_path = r'c:\Users\juanf\Documents\Universidad\Arquitectura de Computadores\FPGA-RiscV32I\rtl\vga\font_rom.v'
    generate_chunky_font(in_path, out_path)
    print("Done generating thick font_rom.v")
