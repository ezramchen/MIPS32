`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: ACU
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

module ACU(
    input [2:0] aluop, // ALU-parsed Opcodes from MCU
    input [5:0] funct, // function code for r-type instructions
    output reg [3:0] actrl // control signal for ALU, MULT/DIV units (up to 16 total operations)
); // arithmetic control unit, decodes opcode and function code to generate control signals for ALU and MULT/DIV units

    // split function bits
    wire [2:0] fn_hi;
    wire [2:0] fn_lo;

    // portion function bits
    assign fn_hi = funct[5:3];
    assign fn_lo = funct[2:0];

    // constants for opcodes and function codes
    localparam [3:0] AND = 4'b0000;
    localparam [3:0] OR = 4'b0001;
    localparam [3:0] ADD = 4'b0010;
    localparam [3:0] XOR = 4'b0011;
    localparam [3:0] ERR = 4'b0100; // error/undefined operation
    localparam [3:0] DIVU = 4'b0101;
    localparam [3:0] SUB = 4'b0110;
    localparam [3:0] SLT = 4'b0111;
    localparam [3:0] SLTU = 4'b1000;
    localparam [3:0] SLL = 4'b1001;
    localparam [3:0] SRL = 4'b1010;
    localparam [3:0] SRA = 4'b1011;
    localparam [3:0] NOR = 4'b1100;
    localparam [3:0] MULT = 4'b1101;
    localparam [3:0] MULTU = 4'b1110;
    localparam [3:0] DIV = 4'b1111;

    // using ALUOp
    always @(*) begin
        actrl = ERR; // default to error/undefined operation
        case(aluop)
            3'b000: actrl = AND; // and, andi
            3'b001: actrl = OR; // or, ori
            3'b010: actrl = ADD; // add, addi, addiu, load, store
            3'b011: actrl = SUB; // sub, beq, bne
            3'b100: actrl = XOR; // xor, xori
            3'b101: actrl = SLT; // slt, slti
            3'b110: actrl = SLTU; // sltu, sltiu
            3'b111: begin 
                case(fn_hi)
                    3'b000: begin
                        case(fn_lo)
                            3'b000: actrl = SLL; // sll
                            3'b010: actrl = SRL; // srl
                            3'b011: actrl = SRA; // sra
                            3'b100: actrl = SLL; // sllv
                            3'b110: actrl = SRL; // srlv
                            3'b111: actrl = SRA; // srav
                        endcase
                    end
                    3'b011: begin
                        case(fn_lo)
                            3'b000: actrl = MULT; // mult
                            3'b001: actrl = MULTU; // multu
                            3'b010: actrl = DIV; // div
                            3'b011: actrl = DIVU; // divu
                        endcase
                    end
                    3'b100: begin
                        case(fn_lo)
                            3'b000: actrl = ADD; // add
                            3'b001: actrl = ADD; // addu
                            3'b010: actrl = SUB; // sub
                            3'b011: actrl = SUB; // subu
                            3'b100: actrl = AND; // and
                            3'b101: actrl = OR; // or
                            3'b110: actrl = XOR; // xor
                            3'b111: actrl = NOR; // nor
                        endcase
                    end
                    3'b101: begin
                        case(fn_lo)
                            3'b010: actrl = SLT; // slt
                            3'b011: actrl = SLTU; // sltu
                        endcase
                    end
                endcase
            end
        endcase
    end
endmodule
