TOOLCHAIN_PATH = ../risccy/xpacks/.bin
CC = $(TOOLCHAIN_PATH)/riscv-none-elf-gcc
AS = $(TOOLCHAIN_PATH)/riscv-none-elf-as
LD = $(TOOLCHAIN_PATH)/riscv-none-elf-ld
CFLAGS = -march=rv32i
OBJCPY = $(TOOLCHAIN_PATH)/riscv-none-elf-objcopy
SOURCES = $(wildcard src/core/*.zig) ./src/main.zig

all: ./src/binaries/boot.bin emulator 

emulator: $(SOURCES)
	zig build-exe src/main.zig --name tentemu

boot.o: ./src/binaries/boot.asm
	$(AS) $(CFLAGS) -o $@ $<

./src/binaries/boot.bin: boot.o
	$(LD) -T ./src/binaries/boot.ld -o boot.elf boot.o
	$(OBJCPY) -O binary --only-section=.text boot.o $@

.PHONY: clean
clean:
	rm -f tentemu tentemu.o boot.elf boot.o
