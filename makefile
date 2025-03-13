#emulator config
ROM_START = 0x10000000
ROM_LENGTH = 0x2000
RAM_LENGTH = 0x800000

#specific to my system
TOOLCHAIN_PATH = ../risccy/xpacks/.bin

#build vars
CC = $(TOOLCHAIN_PATH)/riscv-none-elf-gcc
AS = $(TOOLCHAIN_PATH)/riscv-none-elf-as
LD = $(TOOLCHAIN_PATH)/riscv-none-elf-ld
BOOT_DIR = src/boot
CFLAGS = -march=rv32i -c
OBJCPY = $(TOOLCHAIN_PATH)/riscv-none-elf-objcopy
SOURCES = $(wildcard src/core/*.zig) ./src/main.zig
LINK_FLAGS = --defsym=ROM_START=$(ROM_START) --defsym=ROM_LENGTH=$(ROM_LENGTH) --defsym=RAM_LENGTH=$(RAM_LENGTH)

all: emulator

emulator: $(SOURCES) $(BOOT_DIR)/boot.bin
	zig build-exe src/main.zig --name tentemu -Drom_size=$(ROM_LENGTH) -Dram_size=$(RAM_LENGTH) -Drom_start=$(ROM_START)

boot.o: $(BOOT_DIR)/boot.asm
	$(AS) $(CFLAGS) -o $@ $<

bootc.o: $(BOOT_DIR)/boot.c
	$(CC) $(CFLAGS) -o $@ $<

$(BOOT_DIR)/boot.bin: boot.o bootc.o
	$(LD) -T $(BOOT_DIR)/boot.ld $(LINK_FLAGS) -o boot.elf boot.o bootc.o
	$(OBJCPY) -O binary --only-section=.text boot.elf $@

.PHONY: clean
clean:
	rm -f tentemu tentemu.o boot.elf boot.o bootc.o
