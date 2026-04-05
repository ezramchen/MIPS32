# MIPS32
Near complete pipelined MIPS processor with and without forwarding
<img width="1518" height="885" alt="image" src="https://github.com/user-attachments/assets/22e4e253-e582-44cd-82c5-9a111126d4db" />
organization strategy:
https://student.cs.uwaterloo.ca/~isg/res/mips/opcodes
control structure:
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
