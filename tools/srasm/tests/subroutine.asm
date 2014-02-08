SECTION CODE

    // testing subroutine calls and returns

    bsr     subroutine
    mov     1, r1
    halt

subroutine:
    mov     $aa, r0
    ret

END
