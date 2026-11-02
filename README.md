# MiniRISC: Branch Control and Booth Multiplier Integration

The MiniRISC integrates the PC, synchronous instruction ROM, decoder, register file, immediate generator, ALU, synchronous data BRAM, load/store path, BEQ/BNE branch unit, PC selection, write-back, NOP, HALT, and a control FSM. The fast signed Booth multiplier in `FastBoothMultiplier_58/` is connected to MUL and MAC instructions. The control FSM holds the multiply instruction and PC while the wrapper is busy, then commits the result to a latched destination.

MUL (`01101`) writes the low 32 bits of `rs1 * rs2` to `rd`. MAC (`11010`, using a previously unused opcode) adds the low 32 product bits to the old `rd` value and writes the 32-bit wrapped sum back to `rd`. Both use the R-format field layout documented in `isa.txt`. MAC fetches its accumulator from the register file during the multiply wait after the multiplier has latched its two operands. The hardware wait path is the 28 October stall policy; software NOP scheduling is not required.

The Assignment 5 demonstration first executes the three required signed MUL cases, then computes `[2,-1,3] · [4,5,6]` using LD, MUL, and ADD and stores 21 at data word 8. Its preserved instruction image is `program_assignment5.hex`.

The architectural instruction address is a word index. The RTL represents the PC as a byte address, increments sequentially by four bytes, and uses `PC[9:2]` as the BRAM word address. Branch offsets are signed word offsets relative to the instruction after the branch: `target = PC + 4 + (sign_extend(offset) << 2)`. The ISA supports BEQ and BNE; positive and negative branches are not implemented because the group selected equality and inequality branches.

## Vivado instruction ROM

Create a Block Memory Generator IP named `instruction_rom` with a **Single Port ROM**, depth **256**, width **32**, address width **8**, `clka` clock, `ena` enabled, and a **one-cycle synchronous read**. Disable the optional output register. Initialize it with `program.coe`. The adapter in `instruction_bram_rom.v` uses ports `clka`, `ena`, `addra[7:0]`, and `douta[31:0]`.

## Vivado data memory

Create a Block Memory Generator IP named `data_ram_ip` with a **Single Port RAM**, block RAM primitive, width **32**, depth **256 words**, `ena` enabled, one-bit `wea`, optional output register disabled, and read-during-write mode **No Change**. Initialize it with `data.coe`. Data addresses are word addresses selected directly through `addra[7:0]`.

LD uses the synchronous BRAM read followed by a write-back cycle. HALT holds the PC and instruction and disables further ROM reads, register writes, and data-memory writes until reset.

## Behavioral simulation

With Icarus Verilog installed, run:

```sh
iverilog -g2012 -s tb_minirisc_assignment5 -o /tmp/minirisc_assignment5_tb *.v FastBoothMultiplier_58/*.v simulation/*.v
vvp /tmp/minirisc_assignment5_tb +PROGRAM=program_assignment5.hex +DATA=assignment5
```

The simulation-only BRAM models are in `simulation/`; exclude them from synthesis and use the generated Vivado IP instead. `tb_minirisc_assignment5.v` writes `minirisc_assignment5.vcd` and checks signed results, MUL stalls and write-back, dependent ADDs, BRAM transactions, `Mem[8] = 21`, and HALT. Its named probes include PC/instruction/opcode, FSM state, source operands, multiplier start/busy/done/product, saved destination, register write-back, BRAM address/data/read/write controls, accumulator, result word, and HALT.

The earlier branch and loop demonstration remains available as `program_branch.hex`:

```sh
iverilog -g2012 -s tb_minirisc_basic -o /tmp/minirisc_basic_tb *.v FastBoothMultiplier_58/*.v simulation/*.v
vvp /tmp/minirisc_basic_tb +PROGRAM=program_branch.hex
```

That testbench writes `minirisc_basic.vcd` and checks its branch, load/store, NOP, and HALT behavior.

The CPU-level Booth integration test uses a short program loaded directly into
the behavioral ROM by `tb_minirisc_multiplier.v`. It checks signed MUL,
repeated MAC accumulation for a two-term dot product, multiplier write-back,
destination retention, and PC/ROM stall behavior:

```sh
iverilog -g2012 -s tb_minirisc_multiplier -o /tmp/minirisc_mul_tb *.v FastBoothMultiplier_58/*.v simulation/*.v
vvp /tmp/minirisc_mul_tb
```

The multiplier-specific CPU regression can also be run independently:

```sh
iverilog -g2012 -s tb_minirisc_multiplier -o /tmp/minirisc_mul_tb *.v FastBoothMultiplier_58/*.v simulation/*.v
vvp /tmp/minirisc_mul_tb
```

Vivado-generated BRAM IP and its configuration must be checked in Vivado; the behavioral models verify the documented one-cycle BRAM interface.

## Assignment 6: autonomous four-word sum

The `minirisc32_top` wrapper provides the required `clk`, active-high `reset`,
`done`, and `result_out` interface. It starts at instruction word zero after
reset. The program reads data words 0–3, accumulates 10 + 20 + 30 + 40 in R3,
stores the computed value to word 8, then halts. `result_out` captures the
actual value written by that store and remains stable while halted.

The assignment program is in `Assembler/input.txt` and
`program_assignment6.asm`. To regenerate the assembler image, run
`g++ -std=c++17 -o assembler assembler.cpp && ./assembler` from `Assembler/`;
the assembler writes the same radix-16 image to `Assembler/memory.coe`. The
Vivado instruction image is in
`program.coe`, `program.hex`, and `program_assignment6.coe` (all 11 words).
`data.coe` initializes words 0–3 to 10, 20, 30, and 40, and word 8 to zero.
The simulation data model uses the same values by default.

Run the behavioral simulation from the project root with Icarus Verilog:

```sh
iverilog -g2012 -s tb_minirisc_autonomous -o /tmp/minirisc_assignment6_tb *.v FastBoothMultiplier_58/*.v simulation/*.v
vvp /tmp/minirisc_assignment6_tb
```

`tb_minirisc_autonomous.v` uses the assignment PDF's Section 13 example,
with its original behavior: a 100 MHz clock, reset released after 50 ns,
a wait for `done`, a PASS/FAIL check of `result_out`, and another 100 ns
before finishing. The file retains a `1ns/1ps` timescale declaration.
This example does not contain internal checks, a timeout, or waveform-dump
commands; use the simulator's waveform controls to capture a new waveform.
The existing `minirisc_autonomous.vcd` was generated by the earlier testbench.
Use this same testbench for behavioral and post-implementation timing simulation.

Optional testbench aliases for `pc` and `instruction` are enabled only when
the Verilog macro `RTL_DEBUG_PROBES` is defined. For Icarus behavioral simulation,
add `-DRTL_DEBUG_PROBES` to the compile command. In Vivado, define it only for
behavioral simulation and leave it undefined for post-implementation simulation.
The default testbench references only the mandatory top-level ports, so it does
not depend on internal RTL names surviving synthesis. To inspect PC/instruction
in the implemented design, locate the retained signals in the simulator's
Scopes/Objects windows; their hierarchy and names may differ from the RTL.

For Vivado, set `minirisc32_top` as the design top, initialize the instruction
ROM from `program.coe` and data BRAM from `data.coe`, and apply
`minirisc_assignment6.xdc` (10 ns / 100 MHz). Keep the existing BRAM settings
described above. Run synthesis and implementation, generate the post-implementation
timing simulation model, then compile that model with
`tb_minirisc_autonomous.v`; the expected stable outputs are `done=1` and
`result_out=32'h00000064`. Vivado implementation and timing simulation require
the generated IP and Vivado project, which are not part of this source tree.
