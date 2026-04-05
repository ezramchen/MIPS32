`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: RF
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module RF(
    input clk,
    input rst,
    input [4:0] ra1, // read address 1 (rs)
    input [4:0] ra2, // read address 2 (rt)
    input [4:0] wa, // write address (rd or rt or $ra)
    input [31:0] wd, // write data
    input we, // write enable
    output [31:0] rd1, // read data 1
    output [31:0] rd2 // read data 2
);
    // declare registers
    reg [31:0] regs[0:31]; // ordered from $0 to $31

    // reg selection from instructions
    assign rd1 = (ra1 == 5'b0) ? 32'b0 : regs[ra1]; // if reading $0, return 0, else return register value
    assign rd2 = (ra2 == 5'b0) ? 32'b0 : regs[ra2]; // if reading $0, return 0, else return register value

    // for loops
    integer i;
    // write logic
    always @(posedge clk) begin
        if (rst) begin // on reset, clear all registers to 0
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else begin
            if (we && wa != 5'b0) begin // only write if write enable is high and not writing to $0
                regs[wa] <= wd; // write data to register at write address
            end
        end
    end
endmodule
