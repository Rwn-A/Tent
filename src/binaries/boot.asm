   .section .text
    .global _start

_start:
    li a0, 5       # Load 5 into register a0
    li a1, 10      # Load 10 into register a1
    add a2, a0, a1 # a2 = a0 + a1 (5 + 10 = 15)