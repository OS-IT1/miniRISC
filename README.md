# MiniRISC Assignment 1B

This is the baseline 32-bit datapath for the supplied Assignment 1A ISA: PC (+4), synchronous inferred-BRAM instruction ROM, decode, 16x32 register file, immediate generation, ALU-input mux, ALU and ALU-result write-back.

`program.hex` and `program.coe` execute ADDI, ADD, SUB, AND, SLL, SRL, signed SLT, an attempted R0 write, and HALT. `tb_minirisc_basic.v` self-checks the program, including simultaneous two-register reads and R0 protection. Run the simulation from this directory so the ROM can find `program.hex`. The ROM uses one synchronous port, so a fetch has a one-clock latency. MUL/MAC, data memory, branches and the final control FSM are intentionally deferred as required by Assignment 1B.
