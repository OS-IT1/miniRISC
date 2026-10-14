# MiniRISC Assignment 2A

This is the MiniRISC 32-bit baseline CPU for the ISA documented in `isa.txt`: synchronous instruction ROM, a 16x32 register file, immediate generation, ALU, data memory, write-back, branch comparison, PC selection and a baseline control FSM. The ALU supports signed SLT and SGT comparisons. LD and ST use `rs1 + sign-extended 19-bit offset` as a word effective address; the second register field is the load destination or store source.

BEQ/BNE compare the two register operands and use a signed PC-relative word offset from the instruction after the branch. J uses an absolute word address, while JR loads the byte address from `rs1`. The PC mux supplies the selected next address to the synchronous instruction ROM on the execution edge, so taken transfers do not execute a delay-slot instruction. NOP has no side effects and advances normally. HALT stops PC updates and instruction-ROM reads until reset. The FSM has execute, load-wait and halted states; this preserves the two-phase BRAM load behavior.

`program.hex` and `program.coe` run the Assignment 2A demonstration: initialize base/source registers, load word 5, store 99 to word 5, load it back, then halt. `program_branch.hex` is a separate simulation image that exercises the branch and baseline control instructions. `data.coe` initializes words 0 through 7 to 10, 20, ..., 80.

## Vivado instruction ROM

Create a Block Memory Generator IP named `instruction_rom` with a **Single Port ROM**, depth **256**, width **32**, address width **8**, `clka` clock, `ena` enabled, and a **one-cycle synchronous read**. Disable the optional output register. Initialize it using `program.coe`, and add the generated IP to the project. The adapter in `instruction_bram_rom.v` uses exactly the generated port interface: `clka`, `ena`, `addra`, and `douta`.

The byte-addressed PC becomes the ROM word address `PC[9:2]`. For behavioral simulation outside Vivado, add `simulation/instruction_rom_model.v` to the simulation sources; do not synthesize that model or include it together with the generated IP. Run simulations from this directory so the model can find `program.hex`. MUL/MAC and multiplier scheduling remain deferred.

## Vivado data memory

`data_bram_ram.v` is the adapter for a Vivado Block Memory Generator IP named `data_ram_ip`. Use these settings:

- Memory Type: **Single Port RAM**
- Primitive Type: **Block RAM**
- Port A width: **32 bits**; depth: **256 words**
- Enable Port A (`ena`); keep byte write enables disabled so `wea` is one bit
- Keep the optional output register disabled
- Use ports `clka`, `ena`, `wea`, `addra[7:0]`, `dina[31:0]`, `douta[31:0]`
- Read-during-write mode: **No Change**; initialize with `data.coe` for this assignment's deterministic test

The assignment uses word addresses: each ALU effective address selects one 32-bit word directly through `addra[7:0]`. Add `simulation/data_ram_model.v` to behavioral simulation and exclude it from synthesis when using the generated IP. Initialize the generated IP with `data.coe` for the required deterministic demonstration.

**Timing behavior:** disabling the optional output register does not make a Block RAM read asynchronous. `douta` updates after the active clock edge. The top-level controller therefore gives LD two execute phases: first it issues the address and holds the PC and instruction while BRAM reads; next it writes `douta` to the destination register and resumes fetching. Other implemented instructions, including ST, remain single-cycle.

HALT also holds the PC and disables the instruction ROM on its recognition edge. This keeps the synchronous ROM output parked on the HALT word instead of replacing it with the following instruction. `halted` remains asserted until reset.
During reset the instruction ROM is enabled to replace a parked HALT word and
allow execution to restart from address zero.

## Run the self-checking baseline CPU testbench

With Icarus Verilog installed, run from this directory:

```sh
iverilog -g2012 -s tb_minirisc_basic -o /tmp/minirisc_tb *.v simulation/*.v
vvp /tmp/minirisc_tb +PROGRAM=program_branch.hex
```

The combined bench checks taken and untaken BEQ/BNE, J, JR, NOP, HALT hold,
and the Assignment 2A load/store read-back path. It checks register results
and observes the BRAM interface without reading the memory model's storage
array. The simulation ROM model reads `program.hex` by default; the
`+PROGRAM=...` plusarg selects `program_branch.hex` for this test. The VCD
output is `minirisc_basic.vcd`.
