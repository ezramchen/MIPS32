# Performance Modeling & Design of Pipelined MIPS Processor

This repository contains a Verilog **simulation model** that emulates the behavior of a simplified 32-bit, **5-stage pipelined MIPS processor**. There are two modes:
- **Without forwarding**: illustrates how RAW hazards degrade performance without bypassing
- **With forwarding**: adds forwarding paths and a load-use stall mechanism to mitigate hazards and improve performance

> This project is not fully complete, as it does not properly support certain operations (LUI, incorrect DIV/DIVU cycling)

---

## Pipeline Overview

Both versions follow the classic 5-stage pipeline:

1. **IF**: Instruction Fetch  
2. **ID**: Instruction Decode  
3. **EX**: Execute  
4. **MEM**: Memory Access  
5. **WB**: Write Back  

---

## Main Control Unit

For simplified instruction handling, the (main) control unit outputs a synthesized "32-bit register", with bit-fields allocated as follows:

// MCU output (mctrl): [ WB (6) | MEM (5) | EX (6) | Cntrl Flow (5) | Special (4) | Spare (6) ]
// [31:26] WB = [ RegWr | ResSrc (3) | RegDst (2) ]
// [25:21] MEM = [ MemRd | MemWr | MemSz (2) | LdU ]
// [20:15] EX = [ ALUSrc | ALUOp (3) | ExtOp | ShiftSrc ]
// [14:10] Cntrl Flow = [ Branch | BranchType (2) | Jump | JumpReg ]
// [9:6] Special = [ HIWr | LOWr | HiLoSrc | Trap ]

Some operations were not used in testing (i.e., Trap), and may not work as a result

---

### Instruction File

Since Vivado does not have a MIPS Assembly Compiler, I used ChatGPT to convert assembly into a raw hex file.
Extra load/store instructions were also added to replicate the proper vector behavior.

---

## Version A: Pipeline Without Forwarding (`NoFwd Folder`)

- No hardware forwarding paths are provided
- A **one-cycle flush** is applied on control transfer (control penalty)
- Conservative stalls are included in HAZ_NF to mimic no-early-access behavior

---

## Version B: Pipeline With Forwarding (`Fwd Folder`)

This version includes an additional FWD file and an additional WB MUX

- Forward from **EX/MEM** for ALU results
- Forward from **MEM/WB** for ALU results
- Forward from **MEM/WB** for `lw` results (available after MEM)

### Load-Use Stall

A **1-cycle stall (bubble)** is still required for load-use hazards, because load data is not available until after the MEM stage.

### Hi/Lo Stall

Neither model properly forwards Hi/Lo data due to diminishing returns

### Forwarding Control Signals (as described in the report)

Examples of forwarding/bypass flags used conceptually in the design:

- memF ~ forward from memory
- wbF ~ forward from write-back

---

## Testbenches

One testbench is used:

- `mipsTB`  
  - Designed to handle **both** models
  - Exposes relevant registers for **waveforms**
  - Works in tandem with the "program.mem" hex file

---

## Dot Product Workload

The dot product program computes the dot product of two vectors:

- Vector A: `[0, 1, 7, 0, 8, 3, 1, 8, 3]`
- Vector B: `[9, 0, 6, 9, 7, 2, 0, 7, 2]`

Expected result:

- Dot Product = **166** or **0xA6**

Correctness is verified by observing the accumulation register reaching **166** in simulation waveforms.

---

## Performance Results (From Waveforms)

Completion times reported from waveform markers:

- **Without forwarding**: completes at **2875 ns**
- **With forwarding**: completes at **1575 ns**
- Pipeline cycle time: **10 ns**

Performance improvement:

- Forwarding version finishes **130 cycles earlier**
- Speedup: **2875 / 1575 ≈ 1.825×**

---

## Notes and Limitations

- This is a **Verilog simulation model** of a pipelined MIPS processor, not a fully fleshed-out hardware CPU
- Certain functions remain limited/unoptimized

---

## Repository Layout 

```text
.
├── src/
│   ├── NoFwd/
│   └── Fwd/
├── tb/
│   ├── mipsTB.v
│   └── program.mem
└── report/
    └── EE275p2
```

---

## Author

Ezra Chen
