// Sum four 32-bit words at data addresses 0 through 3 and store at address 8.
// BEQ + absolute J implement the required BZ / BR control flow in this ISA.
        ADDI R1, R0, 0
        ADDI R2, R0, 4
        ADDI R3, R0, 0
LOOP:   LD   R4, 0(R1)
        ADD  R3, R3, R4
        ADDI R1, R1, 1
        SUBI R2, R2, 1
        BEQ  R2, R0, DONE
        J    LOOP
DONE:   ST   R3, 8(R0)
        HALT
