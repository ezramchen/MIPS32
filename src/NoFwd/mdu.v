`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: SJSU
// Engineer: Ezra Chen
// Module Name: MDU
// Project Name: MIPS32
//////////////////////////////////////////////////////////////////////////////////

// incomplete

module MDU(
    input [31:0] a, // input reg A, often rs
    input [31:0] b, // input reg B, often rt
    input [3:0] actrl, // opcodes for mult/div operations from ACU
    output reg [31:0] hi, // hi register output (for mult/div results)
    output reg [31:0] lo // lo register output (for mult/div results
);
    integer i;
    reg [63:0] result; // temporary register for mult/div results (up to 64 bits)
    reg [31:0] a_abs; // absolute value of a for multiplication
    reg [31:0] b_abs; // absolute value of b for multiplication
    wire flip; // for handling signed multiplication
    assign flip = (a[31] ^ b[31]); // if signs of a and b differ, result should be negative

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
