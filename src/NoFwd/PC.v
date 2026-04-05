`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Create Date: 04/04/2026 07:32:05 PM
// Module Name: PC
// Project Name: MIPS
//////////////////////////////////////////////////////////////////////////////////

module PC(
    input clk,
    input rst,
    input en,
    input [31:0] npc, // next program counter from control flow logic
    output reg [31:0] pc // current program counter
);

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'b0; // on reset, set PC to 0
        end else if(en) begin
            pc <= npc; // update PC to next PC on each clock cycle
        end
    end
endmodule
