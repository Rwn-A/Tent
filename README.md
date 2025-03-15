# Tent
A minimal Risc-V implementation. 

## Specification Compliance
- **RV32I Unpriviledged:**\
    Mostly compliant, not sure if every instruction behaves exactly according to spec on edge cases. The ebreak instruction is also not really implemented properly, it is currently being used to help debug the emulator as opposed to debug user code.

- **Zicsr:**\
    CSR instructions are all implemented according to spec, but not all csrs are implemented. See the privileged spec compliance for details.

- **Privileged:**\
    The basic CSR's required for handling environment calls and exceptions are in place but none of the user mode timer CSR's are implemented. the mstatus CSR is partially implemented. Supervisor mode is completely unimplemented but there is some distinction between Machine and User mode however it is not completely spec compliant. Finally, only the mret instruction is implemented.

## Planned Additions
- [ ] More CSR's
- [ ] M extension
- [ ] Memory Mapped IO Interface

## Possible Additions
- [ ] Memory Management Unit
- [ ] F Extension
- [ ] Pipelining
- [ ] Basic Custom Kernel
- [ ] Support for stripped down Linux kernel


## Building
Use `zig build` in the main directory. There are options to specify the RAM/ROM size and location as well as the option to supply your own boot binary. Run `zig build --help` for a description of all config options.

## Memory Map
Right now most of the memory map is configurable. The vector table always starts at the beginning of ROM it is followed immediately by the `_start` function. This means the default program counter position is set to the address imediately after the vector table. The location and size of ROM is configurable, the location and size of RAM is configurable, the location and size of the reserved space for MMIO is configurable, and the size of the vector table is configurable. The linker script for the bootloader is automatically generated if your configuration options are incompatible with eachother it is likely the linker will complain. Finally, the stack_top symbol is set to the top of ram and is defined in the generated linker script. This is currently not configurable.