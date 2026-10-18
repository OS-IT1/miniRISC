# MiniRISC: Branch Control and Booth Multiplier Integration

The MiniRISC integrates the PC, synchronous instruction ROM, decoder, register file, immediate generator, ALU, synchronous data BRAM, load/store path, BEQ/BNE branch unit, PC selection, write-back, NOP, HALT, and a control FSM. The fast signed Booth multiplier in `FastBoothMultiplier_58/` is connected to MUL and MAC instructions. The control FSM holds the multiply instruction and PC while the wrapper is busy, then commits the result to a latched destination.

MUL (`01101`) writes the low 32 bits of `rs1 * rs2` to `rd`. MAC (`11010`, using a previously unused opcode) adds the low 32 product bits to the old `rd` value and writes the 32-bit wrapped sum back to `rd`. Both use the R-format field layout documented in `isa.txt`. MAC fetches its accumulator from the register file during the multiply wait after the multiplier has latched its two operands. The hardware wait path is the 28 October stall policy; software NOP scheduling is not required.

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
iverilog -g2012 -s tb_minirisc_basic -o /tmp/minirisc_tb *.v FastBoothMultiplier_58/*.v simulation/*.v
vvp /tmp/minirisc_tb +PROGRAM=program.hex
```

The simulation-only BRAM models are in `simulation/`; exclude them from synthesis and use the generated Vivado IP instead. `tb_minirisc_basic.v` writes `minirisc_basic.vcd`, with named probes for the assignment's required waveform signals, and checks the loop results, branch PC choices, memory transactions, and multiple HALT cycles.

The CPU-level Booth integration test uses a short program loaded directly into
the behavioral ROM by `tb_minirisc_multiplier.v`. It checks signed MUL,
repeated MAC accumulation for a two-term dot product, multiplier write-back,
destination retention, and PC/ROM stall behavior:

```sh
iverilog -g2012 -s tb_minirisc_multiplier -o /tmp/minirisc_mul_tb *.v FastBoothMultiplier_58/*.v simulation/*.v
vvp /tmp/minirisc_mul_tb
```

## Assignment notes and remaining submission items

Section 10 is demonstrated by the existing 11-word program: initialize R1=3
and R2=1, MOVE R0 into R3, then loop over ADD, ST to word 5, LD into R4,
SUBI, and BNE with offset -5. The three iterations store and reload 1, 2,
and 3. The final BNE and the following BEQ are not taken; NOP and HALT finish
the program at byte PC 40. `program.hex`, `program_branch.hex`, and
`program.coe` contain the same instruction words.

Section 12 signals are mirrored into temporary `reg` variables in the
testbench by a combinational block, so they remain live between clock edges.
These include clock/reset, FSM state, PC/instruction/opcode, source values,
immediate and raw branch offset, ALU result, branch condition/target/decision,
data-BRAM address/read data/write enable, register write enable/write-back,
and halt. Additional probes show register addresses, ALU control, memory
write data/enable, and PC selection.

Assertions verify load issue/commit timing and every load result, branch
conditions and PC updates, NOP register preservation, instruction counts,
final register values, and PC/instruction/register/write-enable preservation
for three clocks after HALT. The testbench is specific to the demonstration
program; a different `+PROGRAM` requires corresponding expected results.

The repository still needs an updated architecture diagram and a full
instruction/control table for submission. `isa.txt` is an opcode/type table,
not the full control table. Add a dot-product program to the instruction ROM
to demonstrate repeated MUL/MAC execution as part of the Assignment 3 demo.
Vivado-generated BRAM IP and its configuration must also be checked in Vivado;
the behavioral models only verify the documented one-cycle BRAM interface.
