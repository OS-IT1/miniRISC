// Assignment 5: signed MUL checks followed by the required three-term dot product.
// Data words: A=[2,-1,3] at 0..2, B=[4,5,6] at 4..6, result at 8.
        addi r1, r0, 7
        addi r2, r0, 9
        mul  r11, r1, r2       // 7 * 9 = 63
        addi r4, r0, -7
        addi r5, r0, 6
        mul  r12, r4, r5       // -7 * 6 = -42
        addi r7, r0, -4
        addi r8, r0, -5
        mul  r13, r7, r8       // -4 * -5 = 20

        addi r10, r0, 0        // ACC = 0
        ld   r1, 0(r0)         // A[0]
        ld   r2, 4(r0)         // B[0]
        mul  r3, r1, r2
        add  r10, r10, r3      // ACC = 8
        ld   r1, 1(r0)         // A[1]
        ld   r2, 5(r0)         // B[1]
        mul  r3, r1, r2
        add  r10, r10, r3      // ACC = 3
        ld   r1, 2(r0)         // A[2]
        ld   r2, 6(r0)         // B[2]
        mul  r3, r1, r2
        add  r10, r10, r3      // ACC = 21
        st   r10, 8(r0)
        ld   r14, 8(r0)         // Read the stored result back through the BRAM interface
        halt
