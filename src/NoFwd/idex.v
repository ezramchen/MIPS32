`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: ID_EX
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module ID_EX(
    input clk,
    input rst,
    input flush,
    input en,

    // ID
    input [31:0] pc4_id,
    input [31:0] rd1_id,
    input [31:0] rd2_id,
    input [31:0] imm_id,
    input [31:0] instr_id,
    input [31:0] mctrl_id,

    // EX
    output reg [31:0] pc4_ex,
    output reg [31:0] rd1_ex,
    output reg [31:0] rd2_ex,
    output reg [31:0] imm_ex,
    output reg [31:0] instr_ex,
    output reg [31:0] mctrl_ex
);

    always @(posedge clk) begin 
        if(rst || flush) begin 
            pc4_ex <= 32'b0;
            rd1_ex <= 32'b0;
            rd2_ex <= 32'b0;
            imm_ex <= 32'b0;
            instr_ex <= 32'b0;
            mctrl_ex <= 32'b0;
        end else if(en) begin 
            pc4_ex <= pc4_id;
            rd1_ex <= rd1_id;
            rd2_ex <= rd2_id;
            imm_ex <= imm_id;
            instr_ex <= instr_id;
            mctrl_ex <= mctrl_id;
        end
    end
endmodule
