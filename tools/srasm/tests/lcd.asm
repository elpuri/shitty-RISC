SECTION CODE


    mov     $30, r0
    mov     l1, r3
    bra     write_lcd_cmd
l1:

    mov     l2, r3
    bra     write_lcd_cmd
l2:

    mov     l3, r3
    bra     write_lcd_cmd
l3:

    mov     $38, r0
    mov     l4, r3
    bra     write_lcd_cmd
l4:

    mov     $0f, r0
    mov     l5, r3
    bra     write_lcd_cmd
l5:

    mov     $01, r0
    mov     l6, r3
    bra     write_lcd_cmd
l6:

    mov     hello_string, r1
    st      r1, str_ptr
write_loop:
    ld      str_ptr, r1
    ld      (r1), r0
    inc     r1
    st      r1, str_ptr     // r1 gets globbered
    mov     0, r3
    add     r3, r0, r0      // yeah need to implement that tst instruction
    breq    write_complete
    mov     write_ret, r3
    bra     write_lcd_data
write_ret:
    bra     write_loop
write_complete:
    halt

// expects command/data in r0 and return address in r3
// waits for ~40us after writing the command/data
write_lcd_data:
    out     r0, $21
    bra     write_lcd_wait
write_lcd_cmd:
    out     r0, $20
write_lcd_wait:
    mov     100, r2

lcd_wait_loop_o:
    mov     255, r1     // 128 * 2 * cycle time = 128 * 2 * 160ns ~= 40us
lcd_wait_loop_i:
    dec     r1
    brne    lcd_wait_loop_i
    dec     r2
    brne    lcd_wait_loop_o
    bra     r3      // return from subroutine

SECTION DATA
hello_string:
    db "Hello World!", 0

str_ptr:
    rb 1
END
