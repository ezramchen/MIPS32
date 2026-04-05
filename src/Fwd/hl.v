`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: HL
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module HL(
    input clk,
    input rst,
    input [31:0] hi_in, // input value for hi register (from MDU)
    input [31:0] lo_in, // input value for lo register (from MDU)
    input hi_wr, // write enable for hi register
    input lo_wr, // write enable for lo register
    output reg [31:0] hi_out, // output value of hi register
    output reg [31:0] lo_out // output value of lo register
); // HI/LO register module, holds values for mult/div results and provides outputs for mfhi/mflo instructions

    always @(posedge clk) begin
        if (rst) begin // on reset, clear hi and lo registers to 0
            hi_out <= 32'b0;
            lo_out <= 32'b0;
        end else begin
            if (hi_wr) begin
                hi_out <= hi_in; // write to hi register on clock edge if enabled
            end
            if (lo_wr) begin
                lo_out <= lo_in; // write to lo register on clock edge if enabled
            end
        end
    end
endmodule
