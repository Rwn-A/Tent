export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\ la sp, stack_top
        \\ call main
        \\j _hang
        \\_hang:
        \\j _hang
    );
}

export fn main() void {}
