`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: IF_ID
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module IF_ID(
    input clk,
    input rst,
    input flush,
    input en,

    // IF
    input [31:0] instr_if,
    input [31:0] pc4_if,

    // ID
    output reg [31:0] instr_id,
    output reg [31:0] pc4_id
); // IF/ID pipeline register

    always @(posedge clk) begin
        if(rst || flush) begin
            instr_id <= 32'b0;
            pc4_id <= 32'b0;
        end else if(en) begin
            instr_id <= instr_if;
            pc4_id <= pc4_if;
        end
    end
endmodule
