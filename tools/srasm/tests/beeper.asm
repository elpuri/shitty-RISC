SECTION CODE

    mov     $0, r2

loop:
    ld      (r2), r3
    out     r3, $10

    mov     15, r0
delay1:
    mov      255, r1e
delay2:
    dec     r1
    brne    delay2
    dec     r0
    brne    delay1

    inc     r2
    mov     $0f, r3
    and     r3, r2, r2
    bra     loop

SECTION DATA

song:
    db 0, 15, 14, 13, 1, 2, 12, 3, 11, 4, 10, 5, 9, 8, 6, 7
END
