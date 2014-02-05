// Ghetto subroutine

SECTION CODE

    mov     10, r0
    mov     return, r1
    bra     sub

return:
    mov     $bb, r3
    halt


sub:
    mov     $aa, r2
    bra     r1

SECTION DATA

ret_addr:
    rb  1
END
