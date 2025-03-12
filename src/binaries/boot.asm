   .text
    .global _start

_start:
    addi x5, x0, 0      # x5 = counter (start at 0)
    
loop:
    # Check if counter (x5) is greater than 10
    slti x6, x5, 10   # x6 = (x5 < 11) ? 1 : 0
    beq x6, x0, exit    # If x6 == 0 (x5 >= 11), exit loop

    addi x5, x5, 1      # counter += 1
    beq x0, x0, loop

exit:
    and x0, x0, x0