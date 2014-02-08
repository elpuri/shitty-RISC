// testing subroutine calls and returns

SECTION CODE
    bsr     subroutine
    mov     1, r1
    halt

subroutine:
    mov     $aa, r0
    ret

END
