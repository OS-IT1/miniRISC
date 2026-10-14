# MiniRISC Assignment 4: Branch Control and Baseline Processor

This MiniRISC baseline integrates the PC, synchronous instruction ROM, decoder, register file, immediate generator, ALU, synchronous data BRAM, load/store path, BEQ/BNE branch unit, PC selection, write-back, NOP, HALT, and a control FSM. MUL/MAC hardware remains deferred as specified in the assignment.

The demonstration program in `program.hex` and `program.coe` initializes a loop counter and increment value, clears an accumulator with MOVE, accumulates with ADD, stores and reloads the result from data BRAM, decrements the counter, and branches back while it is nonzero. The final BNE and an additional BEQ demonstrate the not-taken path, followed by NOP and HALT. The testbench checks ADD, ADDI, SUBI, MOVE, LD, ST, taken and untaken branches, NOP, and HALT.

The architectural instruction address is a word index. The RTL represents the PC as a byte address, increments sequentially by four bytes, and uses `PC[9:2]` as the BRAM word address. Branch offsets are signed word offsets relative to the instruction after the branch: `target = PC + 4 + (sign_extend(offset) << 2)`. The ISA supports BEQ and BNE; positive and negative branches are not implemented because the group selected equality and inequality branches.

## Vivado instruction ROM

Create a Block Memory Generator IP named `instruction_rom` with a **Single Port ROM**, depth **256**, width **32**, address width **8**, `clka` clock, `ena` enabled, and a **one-cycle synchronous read**. Disable the optional output register. Initialize it with `program.coe`. The adapter in `instruction_bram_rom.v` uses ports `clka`, `ena`, `addra[7:0]`, and `douta[31:0]`.

## Vivado data memory

Create a Block Memory Generator IP named `data_ram_ip` with a **Single Port RAM**, block RAM primitive, width **32**, depth **256 words**, `ena` enabled, one-bit `wea`, optional output register disabled, and read-during-write mode **No Change**. Initialize it with `data.coe`. Data addresses are word addresses selected directly through `addra[7:0]`.

LD uses the synchronous BRAM read followed by a write-back cycle. HALT holds the PC and instruction and disables further ROM reads, register writes, and data-memory writes until reset.

## Behavioral simulation

With Icarus Verilog installed, run:

```sh
iverilog -g2012 -s tb_minirisc_basic -o /tmp/minirisc_tb *.v simulation/*.v
vvp /tmp/minirisc_tb +PROGRAM=program.hex
```

The simulation-only BRAM models are in `simulation/`; exclude them from synthesis and use the generated Vivado IP instead. `tb_minirisc_basic.v` writes `minirisc_basic.vcd`, with named probes for the assignment's required waveform signals, and checks the loop results, branch PC choices, memory transactions, and multiple HALT cycles.
