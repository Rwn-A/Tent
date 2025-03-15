pub export fn kernel_main() void {
    asm volatile (
        \\li a7, 1
        \\ecall
    );
}
