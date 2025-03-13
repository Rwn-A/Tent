.text
.global _start
.extern cat

_start:
    la sp, stack_top #set up the stack
    jal ra, main
    j .hang

.hang:
    j .hang
