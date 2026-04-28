I need both read and write to be asynchronous.

The only clock signal there should be is a clock signal that comes from the FPGA, you should not create any other clock signal, and this clock signal should only nurture the program counter.

Also, I need the data memory to have enough space for the program to run but to be smaller so that it can be comfortably fit into the FPGA logic faster.

I heard that when addressing words, half words, and bytes in the data memory there is a better way to do it, explain to me what it would be?