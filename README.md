# 16-bit Single-Cycle Harvard CPU (Verilog)

A clean, modular 16-bit single-cycle processor implemented in Verilog HDL using a **Harvard architecture** (separate instruction and data memories). The design features an 8-register general-purpose register file, a 12-operation ALU with full status flag generation (`C`, `V`, `N`, `Z`), PC-relative conditional branching, register-indirect jumping, and a comprehensive self-checking verification suite.

## Architecture Overview

| Feature | Specification |
| ----- | ----- |
| **Architecture** | Single-cycle, Harvard (separate IMEM & DMEM) |
| **Data Width** | 16-bit |
| **Address / PC Width** | 8-bit (256-word address space) |
| **Instruction Memory** | 256 x 16-bit ROM (unused words pre-filled with `HALT`) |
| **Data Memory** | 256 x 16-bit RAM (synchronous write, asynchronous read) |
| **Register File** | 8 x 16-bit general-purpose registers (`R0`–`R7`), 2 read ports, 1 write port |
| **Status Flags** | `C` (Carry / Borrow), `V` (Signed Overflow), `N` (Negative), `Z` (Zero) |
| **Instruction Count** | 20 instructions across 3 encoding formats |

### Datapath Summary

```text
                +------------------+
                |   Branch Logic   | <--- AD, R[SA] (a_val), branch_z, branch_n, jump
                | PC+se(AD) / a_val|
                +--------+---------+
                         | take, target
                         v
+----+   pc_val   +------+-----+   instr   +---------------+
| PC | ---------> |    IMEM    | --------> | Control Unit  | ---> Control Signals
+----+            | (256 x 16) |     |     +---------------+
                  +------------+     |
                                     +---> DR, SA, SB, OP (zero-ext)
                                     |
                                     v
                              +------+------+   a_val   +-------+   alu_out
                              |  Reg File   | --------> |  ALU  | ----------+---> [C, V, N, Z]
                              |  (8 x 16)   | --b_val-> |       |           |
                              +------+------+   (mux)   +-------+           v
                                     ^             |                     +-----+
                                     |             |    +------------+   | MUX |
                                     |             +--> |    DMEM    | ->|     |
                                     |                  | (256 x 16) |   +--+--+
                                     |                  +------------+      |
                                     +--------------- wr_data --------------+
```

## Repository Structure

| File | Description |
| ----- | ----- |
| `cpu.v` | Top-level processor module connecting the PC, memories, control unit, register file, ALU, and flag registers. |
| `pc.v` | 8-bit Program Counter with synchronous reset, `halt` freeze, and branch/jump target loading. |
| `imem.v` | 256 x 16-bit Instruction Memory loaded via `$readmemh`; unused words default to `16'hFE00` (`HALT`). |
| `dmem.v` | 256 x 16-bit Data Memory initialized to zero. |
| `regfile.v` | 8 x 16-bit Register File (`R0`–`R7`) with two asynchronous read ports (`SA`, `SB`) and one synchronous write port (`DR`). |
| `alu.v` | 16-bit Arithmetic Logic Unit supporting arithmetic, bitwise logic, data movement, shifts, and `C`/`V` flag computation. |
| `control.v` | Combinational Control Unit decoding the 7-bit opcode (`instr[15:9]`). Unknown opcodes safely default to `HALT`. |
| `test_program.hex` | 72-instruction verification program testing all opcodes, flag edge cases, memory access, branches, loops, and jumps. |
| `tb_test.v` | Self-checking testbench that validates flags, intermediate states, and final register/memory values; generates `wave_test.vcd`. |
| `tb_trace.v` | Trace testbench that prints a cycle-by-cycle Markdown execution table of `PC`, instruction, registers, and `CVNZ` flags. |
| `trace.md` | Full execution trace output for `test_program.hex`. |
| `Project.md` | Design notes, instruction encoding diagrams (TikZ), and architecture reference. |
| `waveform.png` | GTKWave simulation screenshot of `wave_test.vcd`. |

## Instruction Set Architecture (ISA)

### Instruction Formats

All instructions are fixed-width 16-bit words:

| Format | `15..9` (7 bits) | `8..6` (3 bits) | `5..3` (3 bits) | `2..0` (3 bits) | Used By |
| ----- | ----- | ----- | ----- | ----- | ----- |
| **(a) Register** | `Opcode` | `DR` | `SA` | `SB` | `MOVA`, `INC`, `ADD`, `SUB`, `DEC`, `AND`, `OR`, `XOR`, `NOT`, `MOVB`, `SHR`, `SHL`, `LD`, `ST` |
| **(b) Immediate** | `Opcode` | `DR` | `SA` | `OP` | `LDI`, `ADI` |
| **(c) Jump & Branch** | `Opcode` | `AD[5:3]` | `SA` | `AD[2:0]` | `BRZ`, `BRN`, `JMP` |

* **`OP`**: 3-bit unsigned immediate (`instr[2:0]`), zero-extended (`zf(OP)`), range `0` to `7`.
* **`AD`**: 6-bit signed branch offset (`{instr[8:6], instr[2:0]}`), sign-extended (`se(AD)`), range `-32` to `+31`.
* **Encoding Examples**:
  * `ADD R3, R1, R2` -> `0000010 011 001 010` = `0x04CA`
  * `ADI R1, R7, 5`  -> `1000010 001 111 101` = `0x847D`
  * `BRN R5, -2`     -> `1100001 111 101 110` = `0xC3EE`

### Complete Instruction Table

| Mnemonic | Opcode (Bin) | Opcode (Hex) | Format | Operands | Operation (RTL) | Updates Flags |
| ----- | ----- | ----- | ----- | ----- | ----- | ----- |
| **MOVA** | `0000000` | `0x00` | Reg | `DR, SA` | `R[DR] = R[SA]` | N, Z (`C=0, V=0`) |
| **INC** | `0000001` | `0x01` | Reg | `DR, SA` | `R[DR] = R[SA] + 1` | C, V, N, Z |
| **ADD** | `0000010` | `0x02` | Reg | `DR, SA, SB` | `R[DR] = R[SA] + R[SB]` | C, V, N, Z |
| **SUB** | `0000101` | `0x05` | Reg | `DR, SA, SB` | `R[DR] = R[SA] - R[SB]` | C, V, N, Z |
| **DEC** | `0000110` | `0x06` | Reg | `DR, SA` | `R[DR] = R[SA] - 1` | C, V, N, Z |
| **AND** | `0001000` | `0x08` | Reg | `DR, SA, SB` | `R[DR] = R[SA] & R[SB]` | N, Z (`C=0, V=0`) |
| **OR** | `0001001` | `0x09` | Reg | `DR, SA, SB` | `R[DR] = R[SA] \| R[SB]` | N, Z (`C=0, V=0`) |
| **XOR** | `0001010` | `0x0A` | Reg | `DR, SA, SB` | `R[DR] = R[SA] ^ R[SB]` | N, Z (`C=0, V=0`) |
| **NOT** | `0001011` | `0x0B` | Reg | `DR, SA` | `R[DR] = ~R[SA]` | N, Z (`C=0, V=0`) |
| **MOVB** | `0001100` | `0x0C` | Reg | `DR, SB` | `R[DR] = R[SB]` | N, Z (`C=0, V=0`) |
| **SHR** | `0001101` | `0x0D` | Reg | `DR, SB` | `R[DR] = R[SB] >> 1` (logical) | N, Z (`C=0, V=0`) |
| **SHL** | `0001110` | `0x0E` | Reg | `DR, SB` | `R[DR] = R[SB] << 1` | N, Z (`C=0, V=0`) |
| **LD** | `0010000` | `0x10` | Reg | `DR, SA` | `R[DR] = DMEM[R[SA][7:0]]` | No |
| **ST** | `0100000` | `0x20` | Reg | `SA, SB` | `DMEM[R[SA][7:0]] = R[SB]` | No |
| **ADI** | `1000010` | `0x42` | Imm | `DR, SA, OP` | `R[DR] = R[SA] + zf(OP)` | C, V, N, Z |
| **LDI** | `1001100` | `0x4C` | Imm | `DR, OP` | `R[DR] = zf(OP)` | No |
| **BRZ** | `1100000` | `0x60` | J/B | `SA, AD` | `if (R[SA] == 0) PC = PC + se(AD)` | No |
| **BRN** | `1100001` | `0x61` | J/B | `SA, AD` | `if (R[SA][15] == 1) PC = PC + se(AD)` | No |
| **JMP** | `1110000` | `0x70` | J/B | `SA` | `PC = R[SA][7:0]` | No |
| **HALT** | `1111111` | `0x7F` | — | — | Freezes PC and asserts `halt` | No |

### Key Architectural Notes

* **Status Flags**:
  * `N` = `alu_out[15]` (MSB / sign bit)
  * `Z` = `(alu_out == 16'd0)`
  * `C` = carry-out for `ADD`/`ADI`/`INC`, or unsigned borrow (`a < b`) for `SUB`/`DEC`; cleared (`0`) for logic, move, and shift operations.
  * `V` = two's-complement signed overflow for arithmetic operations; cleared (`0`) for logic, move, and shift operations.
* **Branching**: `BRZ` and `BRN` test `R[SA]` directly rather than reading the `Z`/`N` status flags. Branch offsets are relative to the branch instruction's own PC address.
* **Building Larger Constants**: Because immediates (`OP`) are 3 bits (`0`–`7`), larger constants or jump addresses are constructed by combining `LDI`, `SHL`, and `ADI`.

## Simulation & Verification

### Prerequisites

* [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` and `vvp`)
* [GTKWave](http://gtkwave.sourceforge.net/) *(optional, for viewing waveforms)*

### 1. Run the Self-Checking Testbench

Compile all CPU modules along with `tb_test.v` and run the simulation:

```bash
iverilog -o sim_test pc.v imem.v dmem.v regfile.v alu.v control.v cpu.v tb_test.v
vvp sim_test
```

**Expected Output:**

```text
--- test_program.hex results ---
R0=7 R1=10 R2=5 R3=0 R4=5 R5=65535 R6=65535 R7=65534
M5=14 M6=19 PC=71 C=0 V=0 N=1 Z=0
ALL TESTS PASSED
```

What `test_program.hex` verifies:

* Flag edge cases: unsigned carry/borrow, signed overflow (`32767 + 1`, `32768 - 1`, etc.), zero and negative flags.
* All ALU operations (`ADD`, `SUB`, `INC`, `DEC`, `MOVA`, `AND`, `OR`, `XOR`, `NOT`, `MOVB`, `SHR`, `SHL`, `ADI`).
* Data memory `ST` and `LD` round-trips.
* `BRZ` and `BRN` both taken and not-taken, plus a backward-branching loop.
* Dynamic address construction (`SHL` + `ADI`) and `JMP`.
* Proper `HALT` assertion at `PC = 71`.

### 2. Generate the Execution Trace

To inspect every instruction cycle in a Markdown table format (matching `trace.md`):

```bash
iverilog -o sim_trace pc.v imem.v dmem.v regfile.v alu.v control.v cpu.v tb_trace.v
vvp sim_trace
```

### 3. View Waveforms

Running `tb_test.v` automatically dumps `wave_test.vcd`. Open it with GTKWave:

```bash
gtkwave wave_test.vcd
```

![App Screenshot](Images/Screenshot%202026-11-25%20175027.png)

*Waveform capture of `test_program.hex` showing clock/reset (`clk`, `rst`), fetched 16-bit instructions (`instr[15:0]`), register file outputs (`a_val`, `b_val`), ALU/write-back values (`alu_out`, `wr_data`), and live status flag transitions (`c_flag`, `n_flag`, `v_flag`, `z_flag`).*

## Running Custom Programs

1. Write your machine code as 16-bit hexadecimal words (one word per line) into a `.hex` file (e.g., `my_prog.hex`).
2. Instantiate the `cpu` module in your testbench with the `PROGRAM_FILE` and `PROG_WORDS` parameters:

```verilog
cpu #(
    .PROGRAM_FILE("my_prog.hex"),
    .PROG_WORDS(16)
) dut (
    .clk(clk),
    .rst(rst),
    .halt(halt)
);
```
