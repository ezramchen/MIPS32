`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: IM
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module IM(
    input [31:0] addr, // address from PC
    output [31:0] instr // instruction at that address
);

    // declare memory
    reg [31:0] mem[0:1023]; // 4KB of memory (1024 words)

    // configure instructions
    assign instr = mem[addr[11:2]]; // word-aligned address, ignore byte offset

    // load instructions
    initial begin 
        $readmemh("program.mem", mem); // load instructions from hex file
    end
endmodule
