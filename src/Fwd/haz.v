`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: HAZ_F
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module HAZ_F(
    // previous GPR
    input [4:0] wa_ex,
    input memrd_ex,

    // current GPR
    input [4:0] rs_id,
    input [4:0] rt_id,
    input uses_rs,
    input uses_rt,

    // previous previous Hi/Lo
    input hiwr_mem,
    input lowr_mem,

    // previous Hi/Lo
    input hiwr_ex,
    input lowr_ex,

    // current Hi/Lo
    input hird_id,
    input lord_id,

    // output
    output stall
);
    
    // types
    wire load_use_stall;
    wire hi_lo_stall;

    // check if same
    wire rs_match;
    wire rt_match;
    assign rs_match = (wa_ex == rs_id);
    assign rt_match = (wa_ex == rt_id);

    // assign stalls
    assign load_use_stall = 
        (memrd_ex && (wa_ex != 5'b0)) &&
        ((uses_rs && rs_match) || (uses_rt && rt_match));

    assign hi_lo_stall = 
        (hird_id && (hiwr_ex || hiwr_mem)) ||
        (lord_id && (lowr_ex || lowr_mem));

    assign stall = load_use_stall || hi_lo_stall;
endmodule
