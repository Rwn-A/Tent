#include <stdint.h>

extern uint32_t stack_top;

// typedef __attribute__((aligned(4))) int8_t aint8_t;
// typedef __attribute__((aligned(4))) int16_t aint16_t;
// typedef __attribute__((aligned(4))) int32_t aint32_t;
// typedef __attribute__((aligned(4))) uint8_t auint8_t;
// typedef __attribute__((aligned(4))) uint16_t auint16_t;
// typedef __attribute__((aligned(4))) uint32_t auint32_t;


// Function prototypes
int32_t add(int32_t a, int32_t b);
int32_t sub(int32_t a, int32_t b);
int32_t xor_op(int32_t a, int32_t b);
int32_t or_op(int32_t a, int32_t b);
int32_t and_op(int32_t a, int32_t b);
int32_t sll(int32_t a, int32_t b);
int32_t slt(int32_t a, int32_t b);
int32_t sltu(uint32_t a, uint32_t b);
int32_t sr(int32_t a, int32_t b);
int32_t lui_test();
int32_t auipc_test();
int32_t jal_test();
void jalr_test();
void branch_tests();
void load_tests();
void store_tests();

int32_t add(int32_t a, int32_t b) { return a + b; }  // ADD
int32_t sub(int32_t a, int32_t b) { return a - b; }  // SUB
int32_t xor_op(int32_t a, int32_t b) { return a ^ b; }  // XOR
int32_t or_op(int32_t a, int32_t b) { return a | b; }  // OR
int32_t and_op(int32_t a, int32_t b) { return a & b; }  // AND
int32_t sll(int32_t a, int32_t b) { return a << (b & 31); }  // SLL
int32_t slt(int32_t a, int32_t b) { return a < b; }  // SLT
int32_t sltu(uint32_t a, uint32_t b) { return a < b; }  // SLTU
int32_t sr(int32_t a, int32_t b) { return a >> (b & 31); }  // SRL/SRA depending on sign

int32_t lui_test() { return 0x12345000; }  // LUI (compiler should generate it)
int32_t auipc_test() { return (int32_t) &auipc_test; }  // AUIPC (compiler should generate it)

int32_t jal_test() {
    return auipc_test();  // A function call should generate JAL
}

void jalr_target() {}  // Target function for JALR
void jalr_test() {
    void (*func_ptr)() = jalr_target;  // Get function pointer
    func_ptr();  // Call via function pointer (JALR)
}

void branch_tests() {
    volatile int a = 10, b = 20;
    if (a == b) {}  // BEQ
    if (a != b) {}  // BNE
    if (a < b) {}  // BLT
    if (a >= b) {}  // BGE
    if ((uint32_t)a < (uint32_t)b) {}  // BLTU
    if ((uint32_t)a >= (uint32_t)b) {}  // BGEU
}

void load_tests() {
    volatile int32_t *ptr = (int32_t *)(&stack_top - 0x1000);
    volatile int8_t b = *(int8_t *)ptr;  // LB
    volatile uint8_t bu = *(uint8_t *)ptr;  // LBU
    volatile int16_t h = *(int16_t *)ptr;  // LH
    volatile uint16_t hu = *(uint16_t *)ptr;  // LHU
    volatile int32_t w = *ptr;  // LW
}

void store_tests() {
    volatile int32_t *ptr = (int32_t *)(&stack_top - 0x1000);
    *(int8_t *)ptr = 0x12;  // SB
    *(int16_t *)ptr = 0x1234;  // SH
    *ptr = 0x12345678;  // SW
}

int main() {
    // Arithmetic tests
    add(1, 2);
    sub(3, 2);
    xor_op(5, 3);
    or_op(6, 2);
    and_op(4, 7);
    sll(1, 2);
    slt(1, 2);
    sltu(1, 2);
    sr(8, 2);

    // Immediate instructions
    lui_test();
    auipc_test();

    // Jumps
    jal_test();
    jalr_test();

    // Branches
    branch_tests();

    // Memory access
    load_tests();
    store_tests();
    return 0;
}
