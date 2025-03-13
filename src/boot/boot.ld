ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = ROM_START, LENGTH = ROM_LENGTH /* 8 KB ROM */
    RAM (rw)  : ORIGIN = ROM_START + ROM_LENGTH, LENGTH = RAM_LENGTH   /* 8 MB RAM */
}

/*0x10000000, 0x10002000*/

SECTIONS
{
    /* ROM Section (Text Section) */
    .text : {
        *(.text)                /* Include all text sections (.text) */
    } > ROM

    /* Data Section (Initialized Data) */
    .data : {
        *(.data)                /* Include all data sections (.data) */
    } > RAM      /* Starts right after ROM (0x10000000 + 8KB = 0x10002000) */

    /* BSS Section (Uninitialized Data) */
    .bss : {
        *(.bss)                 /* Include all uninitialized data sections (.bss) */
    } > RAM
    
    /* End of memory region */
    _end = .;
}
stack_top = ORIGIN(RAM) + LENGTH(RAM);
