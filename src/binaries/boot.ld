/* AI generated, I don't care to become a master of linker scripts*/
ENTRY(_start)            /* Define entry point */

SECTIONS {
    /* Place the .text section (code) at the desired address */
    . = 0x10000000;  /* Change this to your desired address */
    .text : {
        *(.text)      /* Include all .text sections */
        *(.text.*)    /* Include any text-related subsections */
    }

    /* Place the .data section after .text */
    . = ALIGN(4);
    .data : {
        *(.data)
        *(.data.*)
    }

    /* Place the .bss section after .data */
    . = ALIGN(4);
    .bss : {
        *(.bss)
        *(.bss.*)
    }
}