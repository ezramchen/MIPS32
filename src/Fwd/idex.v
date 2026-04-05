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
    input [4:0] wa_id,
    input [4:0] rs_id,
    input [4:0] rt_id,

    // EX
    output reg [31:0] pc4_ex,
    output reg [31:0] rd1_ex,
    output reg [31:0] rd2_ex,
    output reg [31:0] imm_ex,
    output reg [31:0] instr_ex,
    output reg [31:0] mctrl_ex,
    output reg [4:0] wa_ex,
    output reg [4:0] rs_ex,
    output reg [4:0] rt_ex
);

    always @(posedge clk) begin 
        if(rst || flush) begin 
            pc4_ex <= 32'b0;
            rd1_ex <= 32'b0;
            rd2_ex <= 32'b0;
            imm_ex <= 32'b0;
            instr_ex <= 32'b0;
            mctrl_ex <= 32'b0;
            wa_ex <= 5'b0;
            rs_ex <= 5'b0;
            rt_ex <= 5'b0;
        end else if(en) begin 
            pc4_ex <= pc4_id;
            rd1_ex <= rd1_id;
            rd2_ex <= rd2_id;
            imm_ex <= imm_id;
            instr_ex <= instr_id;
            mctrl_ex <= mctrl_id;
            wa_ex <= wa_id;
            rs_ex <= rs_id;
            rt_ex <= rt_id;
        end
    end
endmodule
