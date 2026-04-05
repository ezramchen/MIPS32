`timescale 1ns / 1ps

module mipsTB;

    reg clk;
    reg rst;
    wire [31:0] r1dbg;
    wire [31:0] r7dbg;

    CPU dut (
        .clk(clk),
        .rst(rst),
        .r1dbg(r1dbg),
        .r7dbg(r7dbg)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    // cycle-by-cycle monitor
    always @(posedge clk) begin
        if (!rst) begin
            $display("t=%0t pc=%h instr=%h | r1=%h r2=%h r3=%h r5=%h r7=%h",
                     $time,
                     dut.pc_if,
                     dut.instr_if,
                     dut.Registers.regs[1],
                     dut.Registers.regs[2],
                     dut.Registers.regs[3],
                     dut.Registers.regs[5],
                     dut.Registers.regs[7]);
        end
    end

    initial begin
        clk = 0;
        rst = 1;

        $dumpfile("mipsTB.vcd");
        $dumpvars(0, mipsTB);

        // load instruction memory before releasing reset
        $readmemh("program.mem", dut.InstructionMemory.mem);

        // hold reset long enough for clean startup
        #20;
        rst = 0;

        // run long enough for the full program
        #10000;

        $display("FINAL: r1 = %0d (0x%08h)", dut.Registers.regs[1], dut.Registers.regs[1]);
        $finish;
    end

endmodule
