#specific to my system
TOOLCHAIN_PATH = ../../../risccy/xpacks/.bin

#build vars
CC = $(TOOLCHAIN_PATH)/riscv-none-elf-gcc
AS = $(TOOLCHAIN_PATH)/riscv-none-elf-as
LD = $(TOOLCHAIN_PATH)/riscv-none-elf-ld
OUTPUT = ../../out/$(BIN_NAME)

CFLAGS = -march=rv32i -mabi=ilp32
OBJCPY = $(TOOLCHAIN_PATH)/riscv-none-elf-objcopy
LINK_FLAGS = --defsym=ROM_START=$(ROM_START) --defsym=ROM_LENGTH=$(ROM_SIZE) --defsym=RAM_LENGTH=$(RAM_SIZE)

$(OUTPUT): boot.o bootc.o
	$(LD) -T boot.ld $(LINK_FLAGS) -o boot.elf boot.o bootc.o
	$(OBJCPY) -O binary --only-section=.text boot.elf $@

boot.o: boot.asm
	$(AS) $(CFLAGS) -o $@ $<

bootc.o: boot.c
	$(CC) $(CFLAGS) -c -o $@ $<


.PHONY: clean
clean:
	rm -f boot.elf boot.o bootc.o
