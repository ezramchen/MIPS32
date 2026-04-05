`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: ALU
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module ALU(
    input [31:0] a, // input reg A, often rs
    input [31:0] b, // input reg B, often rt or imm
    input [4:0] shamt, // shift amount for shift operations
    input [3:0] actrl, // opcodes (up to 16 total)
    output reg [31:0] c // output reg c
); // arithmetic logic unit, performs operations based on control signal from ACU

    always @(*) begin
        case(actrl)
            4'b0000: c = a & b; // AND, rs & rt or rs & imm
            4'b0001: c = a | b; // OR, rs | rt or rs | imm
            4'b0010: c = a + b; // ADD, rs + rt or rs + imm
            4'b0011: c = a ^ b; // XOR, rs ^ rt or rs ^ imm
            4'b0110: c = a - b; // SUB, rs - rt or rs - imm
            4'b0111: c = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT, sgn cmp: (rs < rt) or (rs < imm)
            4'b1000: c = (a < b) ? 32'd1 : 32'd0; // SLTU, usgn cmp: (rs < rt) or (rs < imm)
            4'b1001: c = b << shamt; // SLL, rt << shamt
            4'b1010: c = b >> shamt; // SRL, rt >> shamt
            4'b1011: c = $signed(b) >>> shamt; // SRA, rt >> shamt (arith shift)
            4'b1100: c = ~(a | b); // NOR, ~(rs | rt) or ~(rs | imm)
            default: c = 32'hDEADBEEF; // default to error/undefined operation
        endcase
    end
endmodule
