SECTION CODE

    mov     3, r0       // encode on, display on
    out     r0, 4       // display control reg
    in      1, r0

    mov     0, r2
loop:

    mov      20, r0
delay1:
    mov      255, r1e
delay2:
    dec     r1
    brne    delay2
    dec     r0
    brne    delay1

    inc     r2
    out     r2, 0
    bra     loop

END
