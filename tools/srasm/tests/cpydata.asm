SECTION CODE

    mov     foo, r0
    mov     test, r1
    halt

SECTION DATA

free:
    rb 5
test:
    db "testing one two", 0
foo:
    db "bar", 0

END
