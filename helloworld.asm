; assembly language demo for the oc-eight-bit cpu
; instructions:
;  ld
;  mld
;  st
;  add
;  sub
;  eq
;  neq
;  gt
;  lt
;  jmp
;  nop
;  hlt
; compiler-added:
;  rt
;  end
;  lds

; supports routines
rt print
ld 1 10
ld 2 31
ld 3 127
; loop here
mld 4 5
gt 4 2
jmp 4 2
jmp 3 3
lt 4 3
jmp 4 2
jmp 3 3
st 4 255
add 5 1
; jump forward 246 instructions, aka back 9
jmp 3 246
; the loop will exit here
st 1 255
end

; the compiler will convert this to ld/st
lds 0 "Hello world!"
ld 5 0
print
lds 12 "Welcome to the OC-Eight-Bit emulator."
ld 5 12
print
hlt
