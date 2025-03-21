//stack_top, mmio_start are defined in the linker script, which is automatically generated by zig build.
export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, stack_top  
        \\ la t0, mmio_start
        \\ lw t1, 4(t0) #load kernel into ram, get address
        \\ jalr x0, t1, 0 #jump to kernel start
    );
}

//default vector table kernel overwrites with its own at a different address
export fn default_vector_table() linksection(".vect") callconv(.naked) noreturn {
    asm volatile (
        \\ .org  default_vector_table + 0*4
        \\ jal   zero, boot_trap_default
        \\ .org  default_vector_table + 1*4
        \\ jal   zero, boot_trap_default
        \\ .org  default_vector_table + 3*4
        \\ jal   zero, boot_trap_default
        \\ .org  default_vector_table + 5*4
        \\ jal   zero, boot_trap_default
        \\ .org  default_vector_table + 7*4
        \\ jal   zero, boot_trap_default
        \\ .org  default_vector_table + 9*4
        \\ jal   zero, boot_trap_default
        \\ .org  default_vector_table + 11*4
        \\ jal   zero, boot_trap_default
    );
}

//default handler does nothing
export fn boot_trap_default() void {
    asm volatile (
        \\ebreak
        \\mret
    );
}
