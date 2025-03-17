export fn kernel_main() void {
    asm volatile (
        \\la t0, vector_table
        \\csrw mtvec, t0
        \\la t0, mmio_start
        \\li t1, 97
        \\sw t1, 8(t0)
    );
    sys_exit();
}

//overwrite default
export fn vector_table() callconv(.naked) noreturn {
    asm volatile (
        \\ jal   zero, trapDefault
        \\ .org  vector_table + 1*4
        \\ jal   zero, trapDefault
        \\ .org  vector_table + 3*4
        \\ jal   zero, trapDefault
        \\ .org  vector_table + 5*4
        \\ jal   zero, trapDefault
        \\ .org  vector_table + 7*4
        \\ jal   zero, trapDefault
        \\ .org  vector_table + 9*4
        \\ jal   zero, trapDefault
        \\ .org  vector_table + 11*4
        \\ jal   zero, trapEcall
    );
}

export fn trapDefault() void {
    asm volatile (
        \\ebreak
        \\mret
    );
}

export fn trapEcall() void {
    var sys_number: u32 = 0;
    var arg1: u32 = 0;
    var arg2: u32 = 0;
    var arg3: u32 = 0;
    var arg4: u32 = 0;
    var arg5: u32 = 0;
    var arg6: u32 = 0;
    var arg7: u32 = 0;

    asm volatile (
        \\ mv %[sys_number], a7
        \\ mv %[arg1], a0;         
        \\ mv %[arg2], a1        
        \\ mv %[arg3], a2         
        \\ mv %[arg4], a3        
        \\ mv %[arg5], a4        
        \\ mv %[arg6], a5 
        \\ mv %[arg7], a6
        : [sys_number] "=r" (sys_number),
          [arg1] "=r" (arg1),
          [arg2] "=r" (arg2),
          [arg3] "=r" (arg3),
          [arg4] "=r" (arg4),
          [arg5] "=r" (arg5),
          [arg6] "=r" (arg6),
          [arg7] "=r" (arg7),
    );

    switch (sys_number) {
        1 => sys_exit(),
        else => {},
    }

    asm volatile (
        \\ mret
    );
}

export fn sys_exit() noreturn {
    asm volatile (
        \\la t0, mmio_start
        \\li t1, 10
        \\li t2, 3
        \\rem t1, t1, t2
        \\sb t1, 0(t0)
    );
    unreachable;
}
