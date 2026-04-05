`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: FWD
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module FWD(
    // current
    input [4:0] rs_ex,
    input [4:0] rt_ex,

    // previous
    input [4:0] wa_mem,
    input we_mem,

    // previous previous
    input [4:0] wa_wb,
    input we_wb,

    // use?
    input uses_rs,
    input uses_rt,

    // forward
    output reg [1:0] fwdA,
    output reg [1:0] fwdB
);

    // Types
    localparam [1:0] noF = 2'b00;
    localparam [1:0] memF = 2'b10;
    localparam [1:0] wbF = 2'b01;

    always @(*) begin 
        fwdA = noF;
        fwdB = noF; 
        if(we_wb && (wa_wb != 5'b0)) begin // wb
            fwdA = uses_rs && (rs_ex == wa_wb) ? wbF : noF;
            fwdB = uses_rt && (rt_ex == wa_wb) ? wbF : noF;
        end
        if(we_mem && (wa_mem != 5'b0)) begin // mem
            fwdA = uses_rs && (rs_ex == wa_mem) ? memF : fwdA;
            fwdB = uses_rt && (rt_ex == wa_mem) ? memF : fwdB;
        end
    end
endmodule
