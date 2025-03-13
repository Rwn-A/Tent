#emulator config
ROM_START = 268435456 #0x10000000
ROM_SIZE = 8192 #0x2000
RAM_SIZE = 8388608 #0x800000

#specific to my system
TOOLCHAIN_PATH = ../risccy/xpacks/.bin

#build vars
CC = $(TOOLCHAIN_PATH)/riscv-none-elf-gcc
AS = $(TOOLCHAIN_PATH)/riscv-none-elf-as
LD = $(TOOLCHAIN_PATH)/riscv-none-elf-ld
BOOT_DIR = src/boot
CFLAGS = -march=rv32i -mabi=ilp32
OBJCPY = $(TOOLCHAIN_PATH)/riscv-none-elf-objcopy
SOURCES = $(wildcard src/core/*.zig) ./src/main.zig
LINK_FLAGS = --defsym=ROM_START=$(ROM_START) --defsym=ROM_LENGTH=$(ROM_SIZE) --defsym=RAM_LENGTH=$(RAM_SIZE)

all: emulator

emulator: $(SOURCES) $(BOOT_DIR)/boot.bin
	zig build -Dramsize=$(RAM_SIZE) -Dromsize=$(ROM_SIZE) -Dromstart=$(ROM_START)
	cp ./zig-out/bin/Tent ./tentemu 

boot.o: $(BOOT_DIR)/boot.asm
	$(AS) $(CFLAGS) -o $@ $<

bootc.o: $(BOOT_DIR)/boot.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BOOT_DIR)/boot.bin: boot.o bootc.o
	$(LD) -T $(BOOT_DIR)/boot.ld $(LINK_FLAGS) -o boot.elf boot.o bootc.o
	$(OBJCPY) -O binary --only-section=.text boot.elf $@

.PHONY: clean
clean:
	rm -f tentemu tentemu.o boot.elf boot.o bootc.o
