# MiniRISC Assignment 7: autonomous 2×2 matrix multiplication

The processor executes a loop-based program from instruction BRAM after reset. Its
data BRAM contains A = `[[1,2],[3,4]]` at word addresses 0–3, B =
`[[5,6],[7,8]]` at addresses 4–7, and zeroed result locations at 8–11.
The program uses LD, MUL, ADD, immediate arithmetic, BNE and ST to compute and
store C = `[[19,22],[43,50]]`, then executes HALT. Results are produced by
the processor, not by constant stores.

`minirisc32_top` exposes `clk`, active-high `reset`, `done`, and
`result_matrix[127:0]`. The four 32-bit slices from low to high correspond to
C00, C01, C10 and C11. Expected final bus value:
`128'h00000032_0000002B_00000016_00000013`.

The Booth multiplier is the existing signed 32-bit unit under
`FastBoothMultiplier_58/`. The control FSM stops the PC during each MUL until
`multiplier_done`; the dependent ADD then executes. No software NOPs are needed.
The top-level result slices capture the values of actual ST transactions to
data BRAM words 8–11. HALT parks the PC and suppresses register and BRAM writes.

## Program and memory images

`Assembler/input.txt` is the assembly source; `Assembler/memory.coe` is its
generated image. `program.coe` is the same image for Vivado, and `program.hex`
is the same 26 machine words for the behavioral ROM model. Regenerate the
assembler image from the `Assembler/` directory with:

```sh
g++ -std=c++17 -o /tmp/minirisc_assembler assembler.cpp
/tmp/minirisc_assembler
```

`data.coe` initializes 12 words: A, B and four zero results. The behavioral
data model uses the same initial values by default. Data addresses are word
addresses; instruction addresses use byte PC values and `PC[9:2]` for the ROM.
Branches use signed word offsets relative to the instruction after the branch.

## Behavioral simulation

From the repository root, with Icarus Verilog installed:

```sh
iverilog -g2012 -s tb_minirisc_autonomous -o /tmp/minirisc_matrix_tb *.v FastBoothMultiplier_58/*.v simulation/*.v
vvp /tmp/minirisc_matrix_tb
```

`tb_minirisc_autonomous.v` checks 16 loads, eight stalled Booth multiplies,
four consecutive stores at BRAM addresses 8–11, the final BRAM values, the
128-bit output, and stable HALT. It writes `minirisc_matrix.vcd`. The
behavioral ROM may warn that the 26-word hex image is shorter than its
256-word address range; this does not affect execution.

## Vivado implementation and timing simulation

Use `minirisc32_top` as design top. Create a 256×32 single-port synchronous
Block Memory Generator ROM named `instruction_rom`, with `clka`, `ena`,
`addra[7:0]`, `douta[31:0]` and no optional output register. Initialize it
from `program.coe`. Create a 256×32 single-port Block RAM named `data_ram_ip`,
with `clka`, `ena`, one-bit `wea`, `addra[7:0]`, `dina[31:0]`,
`douta[31:0]`, no optional output register, and No Change write mode.
Initialize it from `data.coe`. The `simulation/` memory models are only for
behavioral simulation and must be excluded from synthesis.

Apply `minirisc_assignment6.xdc`, which currently specifies a 20 ns clock;
both testbenches use the same 20 ns period. Check setup and hold slack after
placement and routing. If the implemented design needs a different clock
period, update the XDC and both testbench `CLK_PERIOD` parameters together.
Generate a post-implementation timing simulation model and run it with
`tb_minirisc_autonomous_timing.v` and Vivado's global simulation module.
The timing bench holds reset beyond the 100 ns global reset interval, checks
`done` and all four result words, checks output stability, and writes
`minirisc_matrix_timing.vcd`. Use `run all` in Vivado because the run lasts
more than its default 1000 ns. Bitstream generation is unnecessary.

The source tree does not include a Vivado project, generated BRAM IP, routed
netlist, or post-implementation timing waveform. Those artifacts must be
created in Vivado for the TA demonstration.
