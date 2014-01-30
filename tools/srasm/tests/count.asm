SECTION CODE

    mov     10, r0
    mov     -1, r1e
loop:
    st      r0, (r0)
    add     r1, r0, r0
    brne    loop
    HALT

END
