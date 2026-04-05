`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Create Date: 04/04/2026 11:14:49 PM
// Module Name: CPU
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module mux2_32(
    input [31:0] a,
    input [31:0] b,
    input sel,
    output [31:0] out
);
    // for ALUSrc, ShiftSrc, Branch, and HiLo_in
    assign out = sel ? b : a; // if sel is 1, output b, else output a
endmodule

module mux2_5(
    input [4:0] a,
    input [4:0] b,
    input sel,
    output [4:0] out
);
    // for ShiftSrc
    assign out = sel ? b : a; // if sel is 1, output b, else output a
endmodule

module RDM(
    input [4:0] rt,
    input [4:0] rd,
    input [1:0] sel,
    output reg [4:0] out
); // for RegDst

    always @(*) begin
        case(sel)
            2'b00: out = rt; // rt field is destination (i-type)
            2'b01: out = rd; // rd field is destination (r-type)
            2'b10: out = 5'd31; // $ra is destination (jal, jalr)
            default: out = 5'b0; // default to $0 for invalid sel values
        endcase
    end
endmodule

module WBM(
    input [2:0] ressrc, // select WB source
    input [31:0] alu, // ALU result
    input [31:0] dm, // memory data
    input [31:0] pc4, // PC+4 (for jal, jalr)
    input [31:0] hi, // HI register (for mfhi)
    input [31:0] lo, // LO register (for mflo)
    output reg [31:0] out
); // WB mux

    // for selecting one of five sources
    always @(*) begin
        case (ressrc)
            3'b000: out = alu;
            3'b001: out = dm;
            3'b011: out = pc4;
            3'b100: out = hi;
            3'b101: out = lo;
            default: out = 32'hXXXXXXXX; // for debugging
        endcase
    end
endmodule

module CPU(
    input clk,
    input rst,
    output [31:0] r1dbg,
    output [31:0] r7dbg
); // top-level CPU module
    
    // =========================
    // IF wires
    // =========================
    wire [31:0] pc_if;
    wire [31:0] pc4_if;
    reg  [31:0] npc_if;
    wire [31:0] instr_if;

    // IF/ID control
    wire pc_en;
    wire ifid_en;
    wire ifid_flush;

    // =========================
    // ID wires
    // =========================
    wire [31:0] instr_id;
    wire [31:0] pc4_id;
    wire [31:0] mctrl_id;

    wire [4:0] wa_id;
    wire [31:0] rd1_id;
    wire [31:0] rd2_id;
    wire [31:0] imm_ext_id;

    // decoded fields
    wire [4:0] rs_id;
    wire [4:0] rt_id;
    wire [4:0] rd_id;
    wire [4:0] shamt_id;
    wire [5:0] funct_id;
    wire [5:0] opcode_id;

    // write intent
    wire we_id;
    wire stall;

    // ID/EX control
    wire idex_en;
    wire idex_flush;

    // =========================
    // EX wires
    // =========================
    wire [31:0] instr_ex;
    wire [31:0] pc4_ex;
    wire [31:0] mctrl_ex;

    wire [4:0] wa_ex;
    wire [31:0] rd1_ex;
    wire [31:0] rd2_ex;
    wire [31:0] imm_ext_ex;

    wire we_ex;

    wire [3:0] actrl_ex;
    wire [4:0] shamt_ex;
    wire [31:0] alu_b_ex;
    wire [31:0] alu_out_ex;
    wire [31:0] pc_branch_ex;
    wire [31:0] jump_target_ex;
    wire branch_taken_ex;
    wire control_taken_ex;

    wire [31:0] mdu_hi_ex;
    wire [31:0] mdu_lo_ex;
    wire [31:0] hi_in_ex;
    wire [31:0] lo_in_ex;

    // EX/MEM control
    wire exmem_en;
    wire exmem_flush;

    // =========================
    // MEM wires
    // =========================
    wire [31:0] instr_mem;
    wire [31:0] pc4_mem;
    wire [31:0] mctrl_mem;

    wire [4:0] wa_mem;
    wire [31:0] rd2_mem;
    wire [31:0] alu_out_mem;

    wire we_mem;

    wire [31:0] dm_out_mem;

    wire [31:0] hi_in_mem;
    wire [31:0] lo_in_mem;
    wire [31:0] hi_out_mem;
    wire [31:0] lo_out_mem;

    // MEM/WB control
    wire memwb_en;
    wire memwb_flush;

    // =========================
    // WB wires
    // =========================
    wire [31:0] instr_wb;
    wire [31:0] pc4_wb;
    wire [31:0] mctrl_wb;

    wire [4:0] wa_wb;

    wire [31:0] alu_out_wb;
    wire [31:0] dm_out_wb;
    wire [31:0] hi_out_wb;
    wire [31:0] lo_out_wb;

    wire we_wb;
    wire [31:0] wb_out_wb;

    // =========================
    // Global pipeline control
    // =========================
    assign pc_en       = ~stall;
    assign ifid_en     = ~stall;
    assign idex_en     = 1'b1;
    assign exmem_en    = 1'b1;
    assign memwb_en    = 1'b1;
    
    assign ifid_flush  = control_taken_ex;
    assign idex_flush  = stall || control_taken_ex;
    assign exmem_flush = 1'b0;
    assign memwb_flush = 1'b0;

    // =========================
    // IF stage
    // =========================
    assign pc4_if = pc_if + 32'd4;

    always @(*) begin
        npc_if = pc4_if;
        if (branch_taken_ex) begin
            npc_if = pc_branch_ex;
        end else if (mctrl_ex[11:10] == 2'b10) begin
            npc_if = jump_target_ex;
        end else if (mctrl_ex[11:10] == 2'b11) begin
            npc_if = rd1_ex;
        end
    end

    PC ProgramCounter(
        .clk(clk),
        .rst(rst),
        .en(pc_en),
        .npc(npc_if),
        .pc(pc_if)
    );

    IM InstructionMemory(
        .addr(pc_if),
        .instr(instr_if)
    );

    IF_ID IfIdPipe(
        .clk(clk),
        .rst(rst),
        .flush(ifid_flush),
        .en(ifid_en),
        .instr_if(instr_if),
        .pc4_if(pc4_if),
        .instr_id(instr_id),
        .pc4_id(pc4_id)
    );

    // =========================
    // ID stage
    // =========================
    assign opcode_id = instr_id[31:26];
    assign rs_id     = instr_id[25:21];
    assign rt_id     = instr_id[20:16];
    assign rd_id     = instr_id[15:11];
    assign shamt_id  = instr_id[10:6];
    assign funct_id  = instr_id[5:0];

    MCU Control(
        .opcode(opcode_id),
        .funct(funct_id),
        .mctrl(mctrl_id)
    );

    RDM RegDstMUX_ID(
        .rt(rt_id),
        .rd(rd_id),
        .sel(mctrl_id[27:26]),
        .out(wa_id)
    );

    RF Registers(
        .clk(clk),
        .rst(rst),
        .ra1(rs_id),
        .ra2(rt_id),
        .wa(wa_wb),
        .wd(wb_out_wb),
        .we(we_wb),
        .rd1(rd1_id),
        .rd2(rd2_id)
    );

    mux2_32 ImmExtMUX(
        .a({16'b0, instr_id[15:0]}),
        .b({{16{instr_id[15]}}, instr_id[15:0]}),
        .sel(mctrl_id[16]),
        .out(imm_ext_id)
    );

    HAZ_NF HazardNoFwd(
        .wa_wb(wa_wb),
        .we_wb(we_wb),
        .hiwr_wb(mctrl_wb[9]),
        .lowr_wb(mctrl_wb[8]),
        .wa_mem(wa_mem),
        .we_mem(we_mem),
        .hiwr_mem(mctrl_mem[9]),
        .lowr_mem(mctrl_mem[8]),
        .wa_ex(wa_ex),
        .we_ex(we_ex),
        .hiwr_ex(mctrl_ex[9]),
        .lowr_ex(mctrl_ex[8]),
        .rs_id(rs_id),
        .rt_id(rt_id),
        .ALUSrc_id(mctrl_id[20]),
        .branch_id(mctrl_id[14]),
        .store_id(mctrl_id[24]),
        .jump_id(mctrl_id[11]),
        .jumpreg_id(mctrl_id[10]),
        .hird_id(mctrl_id[30:28] == 3'b100),
        .lord_id(mctrl_id[30:28] == 3'b101),
        .stall(stall)
    );

    assign we_id = mctrl_id[31];
    
    ID_EX IdExPipe(
        .clk(clk),
        .rst(rst),
        .flush(idex_flush),
        .en(idex_en),
        .pc4_id(pc4_id),
        .rd1_id(rd1_id),
        .rd2_id(rd2_id),
        .imm_id(imm_ext_id),
        .instr_id(instr_id),
        .mctrl_id(mctrl_id),
        .pc4_ex(pc4_ex),
        .rd1_ex(rd1_ex),
        .rd2_ex(rd2_ex),
        .imm_ex(imm_ext_ex),
        .instr_ex(instr_ex),
        .mctrl_ex(mctrl_ex)
    );

    // =========================
    // EX stage
    // =========================
    RDM RegDstMUX_EX(
        .rt(instr_ex[20:16]),
        .rd(instr_ex[15:11]),
        .sel(mctrl_ex[27:26]),
        .out(wa_ex)
    );

    ACU ArithmeticControl(
        .aluop(mctrl_ex[19:17]),
        .funct(instr_ex[5:0]),
        .actrl(actrl_ex)
    );

    mux2_32 ALUSrcMUX(
        .a(rd2_ex),
        .b(imm_ext_ex),
        .sel(mctrl_ex[20]),
        .out(alu_b_ex)
    );

    mux2_5 ShiftSrcMUX(
        .a(rd1_ex[4:0]),
        .b(instr_ex[10:6]),
        .sel(mctrl_ex[15]),
        .out(shamt_ex)
    );

    ALU ArithmeticLogicUnit(
        .a(rd1_ex),
        .b(alu_b_ex),
        .shamt(shamt_ex),
        .actrl(actrl_ex),
        .c(alu_out_ex)
    );

    MDU MultDivUnit(
        .a(rd1_ex),
        .b(rd2_ex),
        .actrl(actrl_ex),
        .hi(mdu_hi_ex),
        .lo(mdu_lo_ex)
    );

    assign pc_branch_ex  = pc4_ex + (imm_ext_ex << 2);
    assign jump_target_ex = {pc4_ex[31:28], instr_ex[25:0], 2'b00};

    assign branch_taken_ex = mctrl_ex[14] && (
        ((mctrl_ex[13:12] == 2'b00) && (alu_out_ex == 32'b0)) ||
        ((mctrl_ex[13:12] == 2'b01) && (alu_out_ex != 32'b0)) ||
        ((mctrl_ex[13:12] == 2'b10) && ($signed(rd1_ex) <= 0)) ||
        ((mctrl_ex[13:12] == 2'b11) && ($signed(rd1_ex) > 0))
    );

    assign control_taken_ex = branch_taken_ex || mctrl_ex[11] || mctrl_ex[10];
    assign we_ex = mctrl_ex[31];

    mux2_32 HiMux(
        .a(mdu_hi_ex),
        .b(rd1_ex),
        .sel(mctrl_ex[7]),
        .out(hi_in_ex)
    );

    mux2_32 LoMux(
        .a(mdu_lo_ex),
        .b(rd1_ex),
        .sel(mctrl_ex[7]),
        .out(lo_in_ex)
    );

    EX_MEM ExMemPipe(
        .clk(clk),
        .rst(rst),
        .flush(exmem_flush),
        .en(exmem_en),
        .instr_ex(instr_ex),
        .pc4_ex(pc4_ex),
        .mctrl_ex(mctrl_ex),
        .wa_ex(wa_ex),
        .rd2_ex(rd2_ex),
        .alu_out_ex(alu_out_ex),
        .hi_in_ex(hi_in_ex),
        .lo_in_ex(lo_in_ex),
        .we_ex(we_ex),
        .instr_mem(instr_mem),
        .pc4_mem(pc4_mem),
        .mctrl_mem(mctrl_mem),
        .wa_mem(wa_mem),
        .rd2_mem(rd2_mem),
        .alu_out_mem(alu_out_mem),
        .hi_in_mem(hi_in_mem),
        .lo_in_mem(lo_in_mem),
        .we_mem(we_mem)
    );

    // =========================
    // MEM stage
    // =========================
    DM DataMemory(
        .clk(clk),
        .rst(rst),
        .addr(alu_out_mem),
        .wd(rd2_mem),
        .memctrl(mctrl_mem[25:21]),
        .rd(dm_out_mem)
    );

    HL HiLoRegisters(
        .clk(clk),
        .rst(rst),
        .hi_in(hi_in_mem),
        .lo_in(lo_in_mem),
        .hi_wr(mctrl_mem[9]),
        .lo_wr(mctrl_mem[8]),
        .hi_out(hi_out_mem),
        .lo_out(lo_out_mem)
    );

    MEM_WB MemWbPipe(
        .clk(clk),
        .rst(rst),
        .flush(memwb_flush),
        .en(memwb_en),
        .instr_mem(instr_mem),
        .pc4_mem(pc4_mem),
        .mctrl_mem(mctrl_mem),
        .wa_mem(wa_mem),
        .alu_out_mem(alu_out_mem),
        .dm_out_mem(dm_out_mem),
        .hi_out_mem(hi_out_mem),
        .lo_out_mem(lo_out_mem),
        .we_mem(we_mem),
        .instr_wb(instr_wb),
        .pc4_wb(pc4_wb),
        .mctrl_wb(mctrl_wb),
        .wa_wb(wa_wb),
        .alu_out_wb(alu_out_wb),
        .dm_out_wb(dm_out_wb),
        .hi_out_wb(hi_out_wb),
        .lo_out_wb(lo_out_wb),
        .we_wb(we_wb)
    );

    // =========================
    // WB stage
    // =========================
    WBM WriteBackMux(
        .ressrc(mctrl_wb[30:28]),
        .alu(alu_out_wb),
        .dm(dm_out_wb),
        .pc4(pc4_wb),
        .hi(hi_out_wb),
        .lo(lo_out_wb),
        .out(wb_out_wb)
    );
    
    assign r1dbg = Registers.regs[1];
    assign r7dbg = Registers.regs[7];
    
endmodule
