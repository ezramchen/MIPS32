`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: DM
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

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
