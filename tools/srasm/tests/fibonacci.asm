SECTION CODE

    mov     0, r0       // n-2
    mov     1, r1       // n-1
    mov     2, r2       // memory pointer
    mov     20, r3      // iteration counter
    st      r0, 0       // i'm pedantic
    st      r1, 1
loop:
    st      r2, $ff      // save mem pointer
    add     r0, r1, r2
    mov     r1, r0
    mov     r2, r1
    ld      $ff, r2      // recall mem pointer
    swap    r1
    st      r1, (r2)     // write upper byte result
    inc     r2
    swap    r1
    st      r1, (r2)     // write lower byte result
    inc     r2
    dec     r3
    brne    loop
    halt
END
