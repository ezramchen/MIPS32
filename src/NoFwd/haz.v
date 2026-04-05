`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Create Date: 04/04/2026 11:14:49 PM
// Module Name: CPU
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module HAZ_NF(
    // instruction 0
    input [4:0] wa_wb,
    input we_wb,
    input hiwr_wb,
    input lowr_wb,

    // instruction 1
    input [4:0] wa_mem,
    input we_mem,
    input hiwr_mem,
    input lowr_mem,

    // instruction 2
    input [4:0] wa_ex,
    input we_ex,
    input hiwr_ex,
    input lowr_ex,

    // instruction 3
    input [4:0] rs_id,
    input [4:0] rt_id,
    input ALUSrc_id,
    input branch_id,
    input store_id,
    input jump_id,
    input jumpreg_id,
    input hird_id,
    input lord_id,

    // output
    output stall
);

    // declare types
    wire ex_hazard;
    wire mem_hazard;
    wire wb_hazard;
    wire hilo_hazard;

    // check if used
    wire uses_rs;
    wire uses_rt;
    assign uses_rs = ~jump_id || jumpreg_id; // jump 1 use unless jumpreg 1
    assign uses_rt = ~ALUSrc_id || branch_id || store_id; // (ALUSrc == 0) -> R-type (uses rt), rt skipped if branch/store

    // check if same
    wire rs_ex_match;
    wire rt_ex_match;
    wire rs_mem_match;
    wire rt_mem_match;
    wire rs_wb_match;
    wire rt_wb_match;
    assign rs_ex_match = (wa_ex  == rs_id);
    assign rt_ex_match = (wa_ex  == rt_id);
    assign rs_mem_match = (wa_mem  == rs_id);
    assign rt_mem_match = (wa_mem  == rt_id);
    assign rs_wb_match = (wa_wb  == rs_id);
    assign rt_wb_match = (wa_wb  == rt_id);

    // assign hazards
    assign ex_hazard =
        we_ex && (wa_ex != 5'd0) &&
        ((uses_rs && rs_ex_match) ||
        (uses_rt && rt_ex_match));

    assign mem_hazard =
        we_mem && (wa_mem != 5'd0) &&
        ((uses_rs && rs_mem_match) ||
        (uses_rt && rt_mem_match));

    assign wb_hazard =
        we_wb && (wa_wb != 5'd0) &&
        ((uses_rs && rs_wb_match) ||
        (uses_rt && rt_wb_match));

    assign hilo_hazard = 
        (hird_id && (hiwr_ex || hiwr_mem || hiwr_wb)) ||
        (lord_id && (lowr_ex || lowr_mem || lowr_wb));

    assign stall = ex_hazard || mem_hazard || wb_hazard || hilo_hazard;
endmodule
