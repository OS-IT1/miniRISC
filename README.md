# MiniRISC Assignment 1B

This is the baseline 32-bit datapath for the ISA documented in `isa.txt`: PC (+4), synchronous Vivado-BRAM instruction ROM, decode, 16x32 register file, immediate generation, ALU-input mux, ALU and ALU-result write-back. The ALU and decoder support signed SLT and SGT comparisons.

`program.hex` and `program.coe` execute ADDI, ADD, SUB, AND, SLL, SRL, signed SLT, an attempted R0 write, and HALT. `tb_minirisc_basic.v` self-checks the program, including simultaneous two-register reads and R0 protection.

## Vivado instruction ROM

Create a Block Memory Generator IP named `instruction_rom` with a **Single Port ROM**, depth **256**, width **32**, address width **8**, `clka` clock, `ena` enabled, and a **one-cycle synchronous read**. Disable the optional output register. Initialize it using `program.coe`, and add the generated IP to the project. The adapter in `instruction_bram_rom.v` uses exactly the generated port interface: `clka`, `ena`, `addra`, and `douta`.

The byte-addressed PC becomes the ROM word address `PC[9:2]`. For behavioral simulation outside Vivado, add `simulation/instruction_rom_model.v` to the simulation sources; do not synthesize that model or include it together with the generated IP. Run simulations from this directory so the model can find `program.hex`. MUL/MAC, data memory, branches and the final control FSM are intentionally deferred as required by Assignment 1B.
