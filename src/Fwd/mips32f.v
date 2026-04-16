`default_nettype none
`timescale 1ns / 1ps

// single file version (no debugging)

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

module PC(
    input clk,
    input rst,
    input en,
    input [31:0] npc, // next program counter from control flow logic
    output reg [31:0] pc // current program counter
);

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'b0; // on reset, set PC to 0
        end else if(en) begin
            pc <= npc; // update PC to next PC on each clock cycle
        end
    end
endmodule

// IF

module IM(
    input [31:0] addr, // address from PC
    output [31:0] instr // instruction at that address
);

    // declare memory
    reg [31:0] mem[0:1023]; // 4KB of memory (1024 words)

    // configure instructions
    assign instr = mem[addr[11:2]]; // word-aligned address, ignore byte offset

    // load instructions
    initial begin 
        $readmemh("program.mem", mem); // load instructions from hex file
    end
endmodule

// ID

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

module RF(
    input clk,
    input rst,
    input [4:0] ra1, // read address 1 (rs)
    input [4:0] ra2, // read address 2 (rt)
    input [4:0] wa, // write address (rd or rt or $ra)
    input [31:0] wd, // write data
    input we, // write enable
    output [31:0] rd1, // read data 1
    output [31:0] rd2 // read data 2
);
    // declare registers
    reg [31:0] regs[0:31]; // ordered from $0 to $31

    // reg selection from instructions
    assign rd1 = (ra1 == 5'b0) ? 32'b0 : regs[ra1]; // if reading $0, return 0, else return register value
    assign rd2 = (ra2 == 5'b0) ? 32'b0 : regs[ra2]; // if reading $0, return 0, else return register value

    // for loops
    integer i;

    // write logic
    always @(posedge clk) begin
        if (rst) begin // on reset, clear all registers to 0
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else begin
            if (we && wa != 5'b0) begin // only write if write enable is high and not writing to $0
                regs[wa] <= wd; // write data to register at write address
            end
        end
    end
endmodule

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

// EX

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

module MDU(
    input [31:0] a, // input reg A, often rs
    input [31:0] b, // input reg B, often rt
    input [3:0] actrl, // opcodes for mult/div operations from ACU
    output reg [31:0] hi, // hi register output (for mult/div results)
    output reg [31:0] lo // lo register output (for mult/div results
);

    reg [63:0] result; // temporary register for mult/div results (up to 64 bits)
    reg [31:0] a_abs; // absolute value of a for multiplication
    reg [31:0] b_abs; // absolute value of b for multiplication
    wire flip; // for handling signed multiplication
    assign flip = (a[31] ^ b[31]); // if signs of a and b differ, result should be negative

    // for loops
    integer i;

    always @(*) begin
        hi = 32'b0; // default hi to 0
        lo = 32'b0; // default lo to 0
        case(actrl)
            4'b1101: begin // MULT, cycled with latency
                result = 64'b0; // initialize
                a_abs = (a[31] == 1) ? ~a + 1 : a;
                b_abs = (b[31] == 1) ? ~b + 1 : b;
                for(i = 0; i < 32; i = i + 1) begin
                    result = result + ((b_abs[i] ? ({32'b0, a_abs} << i) : 64'b0)); // add shifted a if bit i of b is set
                end
                if(flip) begin // if result should be negative, take two's complement
                    result = ~result + 1;
                end
                hi = result[63:32]; // upper 32 bits of result go to hi
                lo = result[31:0]; // lower 32 bits of result go to lo
            end
            4'b1110: begin // MULTU, cycled with latency
                result = 64'b0; // initialize
                for(i = 0; i < 32; i = i + 1) begin
                    result = result + ((b[i] ? ({32'b0, a} << i) : 64'b0)); // add shifted a if bit i of b is set
                end
                hi = result[63:32]; // upper 32 bits of result go to hi
                lo = result[31:0]; // lower 32 bits of result go to lo
            end
            4'b1111: begin // DIV, not cycled
                if(b != 0) begin // check for division by zero
                    result = $signed(a) / $signed(b);
                    hi = $signed(a) % $signed(b); // remainder goes to hi
                    lo = $signed(a) / $signed(b); // quotient goes to lo
                end
            end
            4'b0101: begin // DIVU, not cycled
                if(b != 0) begin // check for division by zero
                    result = a / b;
                    hi = a % b; // remainder goes to hi
                    lo = a / b; // quotient goes to lo
                end
            end
            default: begin
                hi = 32'hDEADBEEF; // default to error/undefined operation
                lo = 32'hDEADBEEF; // default to error/undefined operation
            end
        endcase
    end
endmodule

// MEM

module DM(
    input clk,
    input rst,
    input [31:0] addr, // address for load/store
    input [31:0] wd, // write data for store instructions
    input [4:0] memctrl, // memory control signals from MCU (see MCU notes for breakdown)
    output reg [31:0] rd // read data for load instructions
); // data memory module, handles byte/half-word/word loads and stores based on control signals from MCU

    // declare memory
    reg [31:0] mem[0:1023]; // 4KB of memory (1024 words)

    // for readability
    wire [9:0] word;
    assign word = addr[11:2]; // word address (ignoring byte offset), 10-bit address for 1024 words

    // temporary registers for handling byte and half-word accesses
    reg [7:0] btd; // for byte/half-word accesses
    reg [15:0] hfd; // for half-word accesses

    // for loops
    integer i;

    always @(*) begin
        case(addr[1:0]) // byte offset within word
            2'b00: btd = mem[word][7:0];
            2'b01: btd = mem[word][15:8];
            2'b10: btd = mem[word][23:16];
            2'b11: btd = mem[word][31:24];
            default: btd = mem[word][7:0]; // default to first byte for invalid offsets
        endcase
        case(addr[1]) // half-word offset within word
            1'b0: hfd = mem[word][15:0];
            1'b1: hfd = mem[word][31:16];
            default: hfd = mem[word][15:0]; // default to first half-word for invalid offsets
        endcase
        rd = 32'b0; // default read data to 0
        case(memctrl[4:3]) // MemRd/MemWr
            2'b10: begin // load
                case(memctrl[2:0]) // MemSz
                    3'b000: rd = {{24{btd[7]}}, btd}; // lb
                    3'b001: rd = {24'b0, btd}; // lbu
                    3'b010: rd = {{16{hfd[15]}}, hfd}; // lh
                    3'b011: rd = {16'b0, hfd}; // lhu
                    3'b100: rd = mem[word]; // lw
                    default: rd = mem[word]; // default to word for invalid sizes
                endcase
            end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin // on reset, clear all memory to 0
            for (i = 0; i < 1024; i = i + 1) begin
                mem[i] <= 32'b0;
            end
        end else begin
            case(memctrl[4:3]) // MemRd/MemWr
                2'b01: begin // store
                    case(memctrl[2:1]) // MemSz
                            2'b00: begin // sb
                                case(addr[1:0]) // byte offset within word
                                    2'b00: mem[word][7:0] <= wd[7:0];
                                    2'b01: mem[word][15:8] <= wd[7:0];
                                    2'b10: mem[word][23:16] <= wd[7:0];
                                    2'b11: mem[word][31:24] <= wd[7:0];
                                    default: mem[word][7:0] <= wd[7:0]; // default to first byte for invalid offsets
                                endcase
                            end
                            2'b01: begin // sh
                                case(addr[1]) // half-word offset within word
                                    1'b0: mem[word][15:0] <= wd[15:0];
                                    1'b1: mem[word][31:16] <= wd[15:0];
                                    default: mem[word][15:0] <= wd[15:0]; // default to first half-word for invalid offsets
                                endcase
                            end
                            2'b10: mem[word] <= wd; // sw
                            default: mem[word] <= wd; // default to word for invalid sizes
                    endcase
                end
            endcase
        end
    end
endmodule

module HL(
    input clk,
    input rst,
    input [31:0] hi_in, // input value for hi register (from MDU)
    input [31:0] lo_in, // input value for lo register (from MDU)
    input hi_wr, // write enable for hi register
    input lo_wr, // write enable for lo register
    output reg [31:0] hi_out, // output value of hi register
    output reg [31:0] lo_out // output value of lo register
); // HI/LO register module, holds values for mult/div results and provides outputs for mfhi/mflo instructions

    always @(posedge clk) begin
        if (rst) begin // on reset, clear hi and lo registers to 0
            hi_out <= 32'b0;
            lo_out <= 32'b0;
        end else begin
            if (hi_wr) begin
                hi_out <= hi_in; // write to hi register on clock edge if enabled
            end
            if (lo_wr) begin
                lo_out <= lo_in; // write to lo register on clock edge if enabled
            end
        end
    end
endmodule

// WB

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

// Pipes

module IF_ID(
    input clk,
    input rst,
    input flush,
    input en,

    // IF
    input [31:0] instr_if,
    input [31:0] pc4_if,

    // ID
    output reg [31:0] instr_id,
    output reg [31:0] pc4_id
); // IF/ID pipeline register

    always @(posedge clk) begin
        if(rst || flush) begin
            instr_id <= 32'b0;
            pc4_id <= 32'b0;
        end else if(en) begin
            instr_id <= instr_if;
            pc4_id <= pc4_if;
        end
    end
endmodule

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
    input uses_rs_id,
    input uses_rt_id,

    // EX
    output reg [31:0] pc4_ex,
    output reg [31:0] rd1_ex,
    output reg [31:0] rd2_ex,
    output reg [31:0] imm_ex,
    output reg [31:0] instr_ex,
    output reg [31:0] mctrl_ex,
    output reg [4:0] wa_ex,
    output reg [4:0] rs_ex,
    output reg [4:0] rt_ex,
    output reg uses_rs_ex,
    output reg uses_rt_ex
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
            uses_rs_ex <= 1'b0;
            uses_rt_ex <= 1'b0;
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
            uses_rs_ex <= uses_rs_id;
            uses_rt_ex <= uses_rt_id;
        end
    end
endmodule

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

// Hazards/Forwarding

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

// CPU

module CPU(
    input clk,
    input rst
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
    wire stall;

    // =========================
    // ID wires
    // =========================
    wire [31:0] instr_id;
    wire [31:0] pc4_id;
    wire [31:0] mctrl_id;
    wire [31:0] jump_target_id;
    wire control_taken_id;
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

    // ID/EX control
    wire idex_en;
    wire idex_flush;

    // =========================
    // EX wires
    // =========================
    wire [31:0] instr_ex;
    wire [31:0] pc4_ex;
    wire [31:0] mctrl_ex;
    wire [4:0] rs_ex;
    wire [4:0] rt_ex;

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
    wire branch_taken_ex;
    wire control_taken_ex;

    wire [31:0] mdu_hi_ex;
    wire [31:0] mdu_lo_ex;
    wire [31:0] hi_in_ex;
    wire [31:0] lo_in_ex;

    reg [31:0] srcA;
    reg [31:0] srcB;

    // EX/MEM control
    wire exmem_en;
    wire exmem_flush;
    wire [1:0] fwdA;
    wire [1:0] fwdB;

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
    wire [31:0] hi_rd_mem;
    wire [31:0] lo_rd_mem;
    wire [31:0] wb_out_mem;

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

    // Hazard/Forwarding Flags
    
    wire uses_rs_id;
    wire uses_rt_id;

    wire uses_rs_ex;
    wire uses_rt_ex;

    assign uses_rs_id = ~mctrl_id[11] || mctrl_id[10];
    assign uses_rt_id = ~mctrl_id[20] || mctrl_id[14] || mctrl_id[24];

    // =========================
    // Global pipeline control
    // =========================
    assign pc_en       = ~stall;
    assign ifid_en     = ~stall;
    assign idex_en     = 1'b1;
    assign exmem_en    = 1'b1;
    assign memwb_en    = 1'b1;
    assign control_taken_id = ~stall && (mctrl_id[11:10] == 2'b10);
    assign ifid_flush  = control_taken_id || control_taken_ex;
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
        end else if (mctrl_ex[11:10] == 2'b11) begin
            npc_if = srcA;
        end else if (mctrl_id[11:10] == 2'b10) begin
            npc_if = jump_target_id;
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

    assign we_id = mctrl_id[31];

    FWD ForwardUnit(
        .rs_ex(rs_ex),
        .rt_ex(rt_ex),
        .wa_mem(wa_mem),
        .we_mem(we_mem),
        .wa_wb(wa_wb),
        .we_wb(we_wb),
        .uses_rs(uses_rs_ex),
        .uses_rt(uses_rt_ex),
        .fwdA(fwdA),
        .fwdB(fwdB)
    );

    HAZ_F HazardFwd(
        .wa_ex(wa_ex),
        .memrd_ex(mctrl_ex[25]),
        .rs_id(rs_id),
        .rt_id(rt_id),
        .uses_rs(uses_rs_id),
        .uses_rt(uses_rt_id),
        .hiwr_mem(mctrl_mem[9]),
        .lowr_mem(mctrl_mem[8]),
        .hiwr_ex(mctrl_ex[9]),
        .lowr_ex(mctrl_ex[8]),
        .hird_id(mctrl_id[30:28] == 3'b100),
        .lord_id(mctrl_id[30:28] == 3'b101),
        .stall(stall)
    );

    always @(*) begin 
        case(fwdA) 
            2'b00: srcA = rd1_ex;
            2'b10: srcA = wb_out_mem;
            2'b01: srcA = wb_out_wb;
            default: srcA = rd1_ex;
        endcase
        case(fwdB)
            2'b00: srcB = rd2_ex;
            2'b10: srcB = wb_out_mem;
            2'b01: srcB = wb_out_wb;
            default: srcB = rd2_ex;
        endcase
    end

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
        .wa_id(wa_id),
        .rs_id(rs_id),
        .rt_id(rt_id),
        .uses_rs_id(uses_rs_id),
        .uses_rt_id(uses_rt_id),
        .pc4_ex(pc4_ex),
        .rd1_ex(rd1_ex),
        .rd2_ex(rd2_ex),
        .imm_ex(imm_ext_ex),
        .instr_ex(instr_ex),
        .mctrl_ex(mctrl_ex),
        .wa_ex(wa_ex),
        .rs_ex(rs_ex),
        .rt_ex(rt_ex),
        .uses_rs_ex(uses_rs_ex),
        .uses_rt_ex(uses_rt_ex)
    );

    // =========================
    // EX stage
    // =========================

    ACU ArithmeticControl(
        .aluop(mctrl_ex[19:17]),
        .funct(instr_ex[5:0]),
        .actrl(actrl_ex)
    );

    mux2_32 ALUSrcMUX(
        .a(srcB),
        .b(imm_ext_ex),
        .sel(mctrl_ex[20]),
        .out(alu_b_ex)
    );

    mux2_5 ShiftSrcMUX(
        .a(srcA[4:0]),
        .b(instr_ex[10:6]),
        .sel(mctrl_ex[15]),
        .out(shamt_ex)
    );

    ALU ArithmeticLogicUnit(
        .a(srcA),
        .b(alu_b_ex),
        .shamt(shamt_ex),
        .actrl(actrl_ex),
        .c(alu_out_ex)
    );

    MDU MultDivUnit(
        .a(srcA),
        .b(srcB),
        .actrl(actrl_ex),
        .hi(mdu_hi_ex),
        .lo(mdu_lo_ex)
    );

    assign pc_branch_ex  = pc4_ex + (imm_ext_ex << 2);
    assign jump_target_id = {pc4_id[31:28], instr_id[25:0], 2'b00};

    assign branch_taken_ex = mctrl_ex[14] && (
        ((mctrl_ex[13:12] == 2'b00) && (alu_out_ex == 32'b0)) ||
        ((mctrl_ex[13:12] == 2'b01) && (alu_out_ex != 32'b0)) ||
        ((mctrl_ex[13:12] == 2'b10) && ($signed(srcA) <= 0)) ||
        ((mctrl_ex[13:12] == 2'b11) && ($signed(srcA) > 0))
    );

    assign control_taken_ex = branch_taken_ex || (mctrl_ex[11:10] == 2'b11);
    assign we_ex = mctrl_ex[31];

    mux2_32 HiMux(
        .a(mdu_hi_ex),
        .b(srcA),
        .sel(mctrl_ex[7]),
        .out(hi_in_ex)
    );

    mux2_32 LoMux(
        .a(mdu_lo_ex),
        .b(srcA),
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
        .rd2_ex(srcB),
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

    assign hi_rd_mem = mctrl_mem[9] ? hi_in_mem : hi_out_mem;
    assign lo_rd_mem = mctrl_mem[8] ? lo_in_mem : lo_out_mem;

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
        .hi_out_mem(hi_rd_mem),
        .lo_out_mem(lo_rd_mem),
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

    WBM FwdMemMux(
        .ressrc(mctrl_mem[30:28]),
        .alu(alu_out_mem),
        .dm(dm_out_mem),
        .pc4(pc4_mem),
        .hi(hi_rd_mem),
        .lo(lo_rd_mem),
        .out(wb_out_mem)
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

endmodule
