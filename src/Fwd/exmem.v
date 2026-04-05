`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: EX_MEM
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module EX_MEM(
    input clk,
    input rst,
    input flush,
    input en,

    // EX
    input [31:0] instr_ex,
    input [31:0] pc4_ex,
    input [31:0] mctrl_ex,
    input [4:0] wa_ex,
    input [31:0] rd2_ex, 
    input [31:0] alu_out_ex,
    input [31:0] hi_in_ex,
    input [31:0] lo_in_ex,
    input we_ex,

    // MEM
    output reg [31:0] instr_mem,
    output reg [31:0] pc4_mem,
    output reg [31:0] mctrl_mem,
    output reg [4:0] wa_mem,
    output reg [31:0] rd2_mem, 
    output reg [31:0] alu_out_mem,
    output reg [31:0] hi_in_mem,
    output reg [31:0] lo_in_mem,
    output reg we_mem
);

    always @(posedge clk) begin 
        if(rst || flush) begin 
            instr_mem <= 32'b0;
            pc4_mem <= 32'b0;
            mctrl_mem <= 32'b0;
            wa_mem <= 5'b0;
            rd2_mem <= 32'b0;
            alu_out_mem <= 32'b0;
            hi_in_mem <= 32'b0;
            lo_in_mem <= 32'b0;
            we_mem <= 1'b0;
        end else if(en) begin 
            instr_mem <= instr_ex;
            pc4_mem <= pc4_ex;
            mctrl_mem <= mctrl_ex;
            wa_mem <= wa_ex;
            rd2_mem <= rd2_ex;
            alu_out_mem <= alu_out_ex;
            hi_in_mem <= hi_in_ex;
            lo_in_mem <= lo_in_ex;
            we_mem <= we_ex;
        end
    end
endmodule
