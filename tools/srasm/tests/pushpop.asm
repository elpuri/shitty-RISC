// testing push and pop instructions

SECTION CODE
    mov     $aa, r0
    mov     -2, r1e

    push    r0
    push    r1e

    // clobber r0 and r1e
    mov     -1, r0e
    mov     0, r1e

    pop     r1e
    pop     r0

    halt


END
