`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: MEM_WB
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module MEM_WB(
    input clk,
    input rst,
    input flush,
    input en,

    // MEM
    input [31:0] instr_mem,
    input [31:0] pc4_mem,
    input [31:0] mctrl_mem,
    input [4:0] wa_mem,
    input [31:0] alu_out_mem,
    input [31:0] dm_out_mem,
    input [31:0] hi_out_mem,
    input [31:0] lo_out_mem,
    input we_mem,

    // WB
    output reg [31:0] instr_wb,
    output reg [31:0] pc4_wb,
    output reg [31:0] mctrl_wb,
    output reg [4:0] wa_wb,
    output reg [31:0] alu_out_wb,
    output reg [31:0] dm_out_wb,
    output reg [31:0] hi_out_wb,
    output reg [31:0] lo_out_wb,
    output reg we_wb
);

    always @(posedge clk) begin 
        if(rst || flush) begin 
            instr_wb <= 32'b0;
            pc4_wb <= 32'b0;
            mctrl_wb <= 32'b0;
            wa_wb <= 5'b0;
            alu_out_wb <= 32'b0;
            dm_out_wb <= 32'b0;
            hi_out_wb <= 32'b0;
            lo_out_wb <= 32'b0;
            we_wb <= 1'b0;
        end else if(en) begin 
            instr_wb <= instr_mem;
            pc4_wb <= pc4_mem;
            mctrl_wb <= mctrl_mem;
            wa_wb <= wa_mem;
            alu_out_wb <= alu_out_mem;
            dm_out_wb <= dm_out_mem;
            hi_out_wb <= hi_out_mem;
            lo_out_wb <= lo_out_mem;
            we_wb <= we_mem;
        end
    end
endmodule
