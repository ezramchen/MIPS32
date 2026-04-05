`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Create Date: 04/04/2026 07:39:15 PM
// Module Name: IF_ID
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

// MIPS Instruction Format:

// j-type: [ opcode (6) | address (26) ], j 1000
// i-type: [ opcode (6) | rs (5) | rt (5) | imm (16) ], addi $t0, $t1, 10
// r-type: [ opcode (6) | rs (5) | rt (5) | rd (5) | shamt (5) | funct (6) ], add $t0, $t1, $t2
// final register designated (from left to right) is the destination register, and the rest are source registers

// MCU output/Pipeline Register breakdown: [ WB (6) | MEM (5) | EX (6) | Cntrl Flow (5) | Special (4) | Spare (6) ]
// [31:26] WB = [ RegWr | ResSrc (3) | RegDst (2) ]
// [25:21] MEM = [ MemRd | MemWr | MemSz (2) | LdU ]
// [20:15] EX = [ ALUSrc | ALUOp (3) | ExtOp | ShiftSrc ]
// [14:10] Cntrl Flow = [ Branch | BranchType (2) | Jump | JumpReg ]
// [9:6] Special = [ HIWr | LOWr | HiLoSrc | Trap ]

module MCU(
    input [5:0] opcode, // opcode from instruction
    input [5:0] funct, // function code for r-type instructions
    output reg [31:0] mctrl // see notes above for MCU control signal breakdown
);

    // [31] RegWr: 1 = write to register file, 0 = no reg write

    // [30:28] ResSrc: Register sources for writeback
    localparam [2:0] ALU = 3'b000; // ALU path
    localparam [2:0] MEM = 3'b001; // MEM path
    localparam [2:0] PC4 = 3'b011; // PC+4 path, replaces link
    localparam [2:0] HI = 3'b100; // HI path, replaces HiRd
    localparam [2:0] LO = 3'b101; // LO path, replaces LoRd

    // [27:26] RegDst: Register destinations
    localparam [1:0] RT = 2'b00; // rt field is destination (i-type)
    localparam [1:0] RD = 2'b01; // rd field is destination (r-type)
    localparam [1:0] RA = 2'b10; // $ra is destination (jal, jalr)

    // [25] MemRd: 1 = read from memory (load instruction), 0 = no memory read
    // [24] MemWr: 1 = write to memory (store instruction), 0 = no memory write

    // [23:22] Memory sizes (MemSz)
    localparam [1:0] BYTE = 2'b00;
    localparam [1:0] HALF = 2'b01;
    localparam [1:0] WORD = 2'b10;

    // [21] LdU: 1 = load unsigned (zero-extend), 0 = load signed (sign-extend)
    // [20] ALUSrc: 1 = use immediate as ALU input, 0 = use register as ALU input

    // [19:17] Constants for opcodes (ALUOp)
    localparam [2:0] AND = 3'b000; // and, andi
    localparam [2:0] OR = 3'b001; // or, ori
    localparam [2:0] ADD = 3'b010; // add, addi, addiu, load, store
    localparam [2:0] SUB = 3'b011; // sub, beq, bne
    localparam [2:0] XOR = 3'b100; // xor, xori
    localparam [2:0] SLT = 3'b101; // slt, slti
    localparam [2:0] SLTU = 3'b110; // sltu, sltiu
    localparam [2:0] RTP = 3'b111; // r-type

    // [16] ExtOp: 1 = sign-extend immediate, 0 = zero-extend immediate
    // [15] ShiftSrc: 1 = use shamt field as shift amount, 0 = use register value as shift amount
    // [14] Branch: 1 = branch instruction, 0 = not a branch

    // [13:12] branch types
    localparam [1:0] BEQ = 2'b00; // beq, branch checked in ALU
    localparam [1:0] BNE = 2'b01; // bne, branch checked in ALU
    localparam [1:0] BLEZ = 2'b10; // blez, branch checked outside ALU (check if rs <= 0)
    localparam [1:0] BGTZ = 2'b11; // bgtz, branch checked outside ALU (check if rs > 0)

    // [11] Jump: 1 = jump instruction, 0 = not a jump
    // [10] JumpReg: 1 = jump register instruction (jr, jalr), 0 = not a jump register
    // [9] HIWr: 1 = write to HI register (mthi), 0 = no write to HI
    // [8] LOWr: 1 = write to LO register (mtlo), 0 = no write to LO
    // [7] HiLoSrc: 1 = write from RS to HI/LO, 0 = write from MDU to HI/LO (handled by ResSrc)
    // [6] Trap: 1 = trap instruction, 0 = not a trap

    // from MIPS map
    always @(*) begin
        mctrl = 32'b0; // default to all control signals low
        casez(opcode)
            6'b000000: begin // r-type
                mctrl[31:26] = {1'b1, ALU, RD}; // reg write, write from ALU, reg dest is rd
                mctrl[20:16] = {1'b0, RTP, 1'b0}; // reg -> ALU, ALUOp = r-type, no imm, check later for shift
                casez(funct) // jumps
                    6'b001000: begin // jr
                        mctrl[31:26] = {6'b0}; // no reg write, ignore path/dest
                        mctrl[14:10] = {3'b0, 1'b1, 1'b1}; // no branch, jump, jump reg
                    end
                    6'b001001: begin // jalr
                        mctrl[31:26] = {1'b1, PC4, RD}; // reg write, write PC+4 to $rd
                        mctrl[14:10] = {3'b0, 1'b1, 1'b1}; // no branch, jump, jump reg
                    end
                    6'b0000??: begin 
                        mctrl[15] = 1'b1; // shift instruction, use shamt as shift amount
                    end
                    6'b010000: begin // mfhi
                        mctrl[31:26] = {1'b1, HI, RD}; // reg write, write from HI, reg dest is rd
                    end
                    6'b010001: begin // mthi
                        mctrl[31:26] = 6'b0; // no GPR write, ignore path/dest
                        mctrl[9:6] = {1'b1, 1'b0, 1'b1, 1'b0}; // write to HI register, write from RS to HI/LO, no trap
                    end
                    6'b010010: begin // mflo
                        mctrl[31:26] = {1'b1, LO, RD}; // reg write, write from LO, reg dest is rd
                    end
                    6'b010011: begin // mtlo
                        mctrl[31:26] = 6'b0; // no GPR write, ignore path/dest
                        mctrl[9:6] = {1'b0, 1'b1, 1'b1, 1'b0}; // write to LO register, write from RS to HI/LO, no trap
                    end
                    6'b011???: begin // mult/div operations
                        mctrl[31:26] = 6'b0; // no GPR write, ignore path/dest
                        mctrl[9:6] = {1'b1, 1'b1, 1'b0, 1'b0}; // write to HI/LO, no trap
                    end
                endcase
            end
            6'b000010: begin // j
                mctrl[14:10] = {3'b0, 1'b1, 1'b0}; // no branch, jump, no jump reg
            end
            6'b000011: begin // jal
                mctrl[31:26] = {1'b1, PC4, RA}; // reg write, write PC+4 to $ra
                mctrl[14:10] = {3'b0, 1'b1, 1'b0}; // no branch, jump, no jump reg
            end
            6'b000100: begin // beq
                mctrl[20:15] = {1'b0, SUB, 2'b0}; // reg -> ALU, ALUOp = SUB for cmp, no imm, no shift
                mctrl[14:10] = {1'b1, BEQ, 2'b0}; // branch, beq type, no jump, no jump reg
            end
            6'b000101: begin // bne
                mctrl[20:15] = {1'b0, SUB, 2'b0}; // reg -> ALU, ALUOp = SUB for cmp, no imm, no shift
                mctrl[14:10] = {1'b1, BNE, 2'b0}; // branch, bne type, no jump, no jump reg
            end
            6'b000110: begin // blez
                mctrl[14:10] = {1'b1, BLEZ, 2'b0}; // branch, blez type, no jump, no jump reg
            end
            6'b000111: begin // bgtz
                mctrl[14:10] = {1'b1, BGTZ, 2'b0}; // branch, bgtz type, no jump, no jump reg
            end
            6'b00100?: begin // addi, addiu
                mctrl[31:26] = {1'b1, ALU, RT}; // reg write, write from ALU, reg dest is rt
                mctrl[20:15] = {1'b1, ADD, 1'b1, 1'b0}; // imm -> ALU, ALUOp = ADD for addi/addiu, sign-extend, no shift
            end
            6'b10????: begin // load/store
                mctrl[20:15] = {1'b1, ADD, 1'b1, 1'b0}; // imm -> ALU, ALUOp = ADD for address calc, sign-extend, no shift
                case(opcode[3])
                    1'b0: begin // load
                        mctrl[31:26] = {1'b1, MEM, RT}; // reg write, write from MEM, reg dest is rt
                        mctrl[25:24] = {1'b1, 1'b0}; // memory read, no memory write
                        case(opcode[2]) // load type (signed vs unsigned)
                            1'b0: mctrl[21] = 1'b0; // load signed
                            1'b1: mctrl[21] = 1'b1; // load unsigned
                        endcase
                    end
                    1'b1: begin // store
                        mctrl[25:24] = {1'b0, 1'b1}; // no memory read, memory write
                    end
                endcase
                case(opcode[1:0]) // memory size
                    2'b00: mctrl[23:22] = BYTE; // byte
                    2'b01: mctrl[23:22] = HALF; // half-word
                    2'b11: mctrl[23:22] = WORD; // word
                    default: mctrl[23:22] = WORD; // default to word for invalid sizes
                endcase
            end
            6'b001010: begin // slti
                mctrl[31:26] = {1'b1, ALU, RT}; // reg write, write from ALU, reg dest is rt
                mctrl[20:15] = {1'b1, SLT, 1'b1, 1'b0}; // imm -> ALU, ALUOp = SLT for slti, sign-extend, no shift
            end
            6'b001011: begin // sltiu
                mctrl[31:26] = {1'b1, ALU, RT}; // reg write, write from ALU, reg dest is rt
                mctrl[20:15] = {1'b1, SLTU, 1'b1, 1'b0}; // imm -> ALU, ALUOp = SLTU for sltiu, sign-extend, no shift
            end
            6'b001100: begin // andi
                mctrl[31:26] = {1'b1, ALU, RT}; // reg write, write from ALU, reg dest is rt
                mctrl[20:15] = {1'b1, AND, 1'b0, 1'b0}; // imm -> ALU, ALUOp = AND for andi, zero-extend, no shift
            end
            6'b001101: begin // ori
                mctrl[31:26] = {1'b1, ALU, RT}; // reg write, write from ALU, reg dest is rt
                mctrl[20:15] = {1'b1, OR, 1'b0, 1'b0}; // imm -> ALU, ALUOp = OR for ori, zero-extend, no shift
            end
            6'b001110: begin // xori
                mctrl[31:26] = {1'b1, ALU, RT}; // reg write, write from ALU, reg dest is rt
                mctrl[20:15] = {1'b1, XOR, 1'b0, 1'b0}; // imm -> ALU, ALUOp = XOR for xori, zero-extend, no shift
            end
            default: mctrl[20:15] = {1'b1, ADD, 1'b1, 1'b0}; // default = ADD (handled downstream)
        endcase
    end
endmodule
