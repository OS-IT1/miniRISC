# MiniRISC Assignment 1B

This is the MiniRISC 32-bit datapath for the ISA documented in `isa.txt`: PC (+4), synchronous instruction ROM, decode, 16x32 register file, immediate generation, ALU-input mux, ALU, data memory and write-back. The ALU and decoder support signed SLT and SGT comparisons. LD and ST use `rs1 + sign-extended 19-bit offset` as a byte effective address; the second register field is the load destination or store source.

`program.hex` and `program.coe` execute ADDI, ADD, SUB, AND, SLL, SRL, signed SLT, an attempted R0 write, and HALT. `tb_minirisc_basic.v` self-checks the program, including simultaneous two-register reads and R0 protection.

## Vivado instruction ROM

Create a Block Memory Generator IP named `instruction_rom` with a **Single Port ROM**, depth **256**, width **32**, address width **8**, `clka` clock, `ena` enabled, and a **one-cycle synchronous read**. Disable the optional output register. Initialize it using `program.coe`, and add the generated IP to the project. The adapter in `instruction_bram_rom.v` uses exactly the generated port interface: `clka`, `ena`, `addra`, and `douta`.

The byte-addressed PC becomes the ROM word address `PC[9:2]`. For behavioral simulation outside Vivado, add `simulation/instruction_rom_model.v` to the simulation sources; do not synthesize that model or include it together with the generated IP. Run simulations from this directory so the model can find `program.hex`. MUL/MAC, branches and the final control FSM remain deferred.

## Vivado data memory

`data_bram_ram.v` is the adapter for a Vivado Block Memory Generator IP named `data_ram_ip`. Use these settings:

- Memory Type: **Single Port RAM**
- Primitive Type: **Block RAM**
- Port A width: **32 bits**; depth: **256 words**
- Enable Port A (`ena`); keep byte write enables disabled so `wea` is one bit
- Keep the optional output register disabled
- Use ports `clka`, `ena`, `wea`, `addra[7:0]`, `dina[31:0]`, `douta[31:0]`
- Read-during-write mode: **No Change**; no initialization file is needed unless you want preset data

The CPU uses effective address bits `[9:2]`, so memory covers 1 KiB of byte addresses and accesses aligned words; the low two address bits are ignored. Add `simulation/data_ram_model.v` to behavioral simulation and exclude it from synthesis when using the generated IP.

**Timing behavior:** disabling the optional output register does not make a Block RAM read asynchronous. `douta` updates after the active clock edge. The top-level controller therefore gives LD two execute phases: first it issues the address and holds the PC and instruction while BRAM reads; next it writes `douta` to the destination register and resumes fetching. Other implemented instructions, including ST, remain single-cycle.

HALT also holds the PC and disables the instruction ROM on its recognition edge. This keeps the synchronous ROM output parked on the HALT word instead of replacing it with the following instruction. `halted` remains asserted until reset.
