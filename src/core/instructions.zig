const std = @import("std");

const sext = @import("cpu.zig").sext;
const zext = @import("cpu.zig").zext;

// Type definitions and decoding logic for RiscV instructions.
// Some of the immediate decoding logic was done with AI, although it took alot of coercing to get right.
// I am not a bit-fiddling master so there is a good chance some of the decodes are slow and/or inelegant.

const DecodeError = error{UnknownInstruction};

pub const Instr_Function = enum(u32) {
    Lb, // load byte
    Lh, // load halfword
    Lw, // load word
    Lbu, // load byte unsigned
    Lhu, // load halfword unsigned

    Addi, // add immediate
    Slti, // set less than immediate (signed)
    Sltiu, // set less than immediate (unsigned)
    Xori, // xor immediate
    Ori, // or immediate
    Andi, // and immediate

    Slli,
    Srli,
    Srai,

    Add, // add
    Sub, // subtract
    Sll, // shift left logical
    Slt, // set less than (signed)
    Sltu, // set less than (unsigned)
    Xor, // xor
    Srl, // shift right logical
    Sra, // shift right arithmetic
    Or, // or
    And, // and

    Jalr, // jump and link register

    Jal, // jump

    Ecall, // environment call
    Ebreak, // environment break

    Beq, // branch if equal
    Bne, // branch if not equal
    Blt, // branch if less than (signed)
    Bge, // branch if greater or equal (signed)
    Bltu, // branch if less than (unsigned)
    Bgeu, // branch if greater or equal (unsigned)

    Sb, // store byte
    Sh, // store halfword
    Sw, // store word

    Lui, // load upper immediate
    Auipc, // add upper immediate
};

pub const I_Type_Instr = struct {
    function: Instr_Function,
    rd: u32,
    rs1: u32,
    imm: u32,
};

pub const R_Type_Instr = struct {
    function: Instr_Function,
    rd: u32,
    rs1: u32,
    rs2: u32,
};

pub const B_Type_Instr = struct {
    function: Instr_Function,
    rs1: u32,
    rs2: u32,
    imm: u32,
};

pub const S_Type_Instr = struct {
    function: Instr_Function,
    rs1: u32,
    rs2: u32,
    imm: u32,
};

pub const J_Type_Instr = struct {
    function: Instr_Function,
    imm: u32,
    rd: u32,
};

pub const U_Type_Instr = struct {
    function: Instr_Function,
    imm: u32,
    rd: u32,
};

pub const Instruction = union(enum) {
    I_type: I_Type_Instr,
    R_type: R_Type_Instr,
    B_type: B_Type_Instr,
    S_type: S_Type_Instr,
    J_type: J_Type_Instr,
    U_type: U_Type_Instr,

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .I_type => |inst| {
                try writer.print("{s}, x{d}, x{d}, {d}", .{ @tagName(inst.function), inst.rd, inst.rs1, @as(i32, @bitCast(inst.imm)) });
            },
            .R_type => |inst| {
                try writer.print("{s}, x{d}, x{d}, x{d}", .{ @tagName(inst.function), inst.rd, inst.rs1, inst.rs2 });
            },
            .B_type => |inst| {
                try writer.print("{s}, x{d}, x{d}, {d}", .{ @tagName(inst.function), inst.rs1, inst.rs2, @as(i32, @bitCast(inst.imm)) });
            },
            .S_type => |inst| {
                try writer.print("{s}, x{d}, x{d}, {d}", .{ @tagName(inst.function), inst.rs1, inst.rs2, @as(i32, @bitCast(inst.imm)) });
            },
            .J_type => |inst| {
                try writer.print("{s}, x{d}, {d}", .{ @tagName(inst.function), inst.rd, @as(i32, @bitCast(inst.imm)) });
            },
            .U_type => |inst| {
                try writer.print("{s}, x{d}, {d}", .{ @tagName(inst.function), inst.rd, @as(u32, @bitCast(inst.imm)) });
            },
        }
    }
};

pub fn decode(encoded_instruction: u32) DecodeError!Instruction {
    return switch (get_field(encoded_instruction, 0, 7)) {
        0x33 => .{ .R_type = try decode_R_type_instr(encoded_instruction) },
        0x63 => .{ .B_type = try decode_B_type_instr(encoded_instruction) },
        0x23 => .{ .S_type = try decode_S_type_instr(encoded_instruction) },
        0x6F => .{ .J_type = try decode_J_type_instr(encoded_instruction) },
        0x37, 0x17 => return .{ .U_type = try decode_U_type_instr(encoded_instruction) },
        0x03, 0x67, 0x13, 0x73 => .{ .I_type = try decode_I_type_instr(encoded_instruction) },
        else => return DecodeError.UnknownInstruction,
    };
}

fn decode_I_type_instr(encoded_instruction: u32) DecodeError!I_Type_Instr {
    var result: I_Type_Instr = undefined;
    const opc = get_field(encoded_instruction, 0, 7);
    const funct3 = get_field(encoded_instruction, 12, 3);
    result.rd = get_field(encoded_instruction, 7, 5);
    result.rs1 = get_field(encoded_instruction, 15, 5);
    result.imm = sext(get_field(encoded_instruction, 20, 12), 12);
    result.function = switch (opc) {
        0x13 => switch (funct3) {
            0b000 => .Addi,
            0b010 => .Slti,
            0b011 => .Sltiu,
            0b100 => .Xori,
            0b110 => .Ori,
            0b111 => .Andi,
            0b001 => blk: {
                result.imm = zext(get_field(encoded_instruction, 20, 5), 5);
                break :blk .Slli;
            },
            0b101 => blk: {
                result.imm = zext(get_field(encoded_instruction, 20, 5), 5);
                break :blk switch (get_field(encoded_instruction, 30, 1)) {
                    0b1 => .Srai,
                    0b0 => .Srli,
                    else => return DecodeError.UnknownInstruction,
                };
            },
            else => return DecodeError.UnknownInstruction,
        },
        0x03 => switch (funct3) {
            0b000 => .Lb,
            0b001 => .Lh,
            0b010 => .Lw,
            0b100 => .Lbu,
            0b101 => .Lhu,
            else => return DecodeError.UnknownInstruction,
        },
        0x73 => switch (funct3) {
            0b000 => .Ecall,
            0b001 => .Ebreak,
            else => return DecodeError.UnknownInstruction,
        },
        0x67 => .Jalr,
        else => return DecodeError.UnknownInstruction,
    };
    return result;
}

fn decode_J_type_instr(encoded_instruction: u32) DecodeError!J_Type_Instr {
    var result: J_Type_Instr = undefined;
    result.rd = get_field(encoded_instruction, 7, 5);
    const imm20 = get_field(encoded_instruction, 31, 1);
    const imm10_1 = get_field(encoded_instruction, 21, 10);
    const imm11 = get_field(encoded_instruction, 20, 1);
    const imm19_12 = get_field(encoded_instruction, 12, 8);
    result.imm = sext((imm20 << 19) | (imm19_12 << 12) | (imm10_1 << 1) | (imm11 << 11), 20);
    result.function = .Jal;
    return result;
}

fn decode_U_type_instr(encoded_instruction: u32) DecodeError!U_Type_Instr {
    var result: U_Type_Instr = undefined;
    const opc = get_field(encoded_instruction, 0, 7);
    result.function = if (opc == 0x37) .Lui else .Auipc;
    result.rd = get_field(encoded_instruction, 7, 5);
    result.imm = zext(get_field(encoded_instruction, 12, 20), 20);
    return result;
}

fn decode_S_type_instr(encoded_instruction: u32) DecodeError!S_Type_Instr {
    var result: S_Type_Instr = undefined;
    const funct3 = get_field(encoded_instruction, 12, 3);
    result.rs1 = get_field(encoded_instruction, 15, 5);
    result.rs2 = get_field(encoded_instruction, 20, 5);
    const imm11_5 = get_field(encoded_instruction, 25, 7);
    const imm4_0 = get_field(encoded_instruction, 7, 5);
    result.imm = sext(imm11_5 << 5 | imm4_0, 12);
    result.function = switch (funct3) {
        0b000 => .Sb,
        0b001 => .Sh,
        0b010 => .Sw,
        else => return DecodeError.UnknownInstruction,
    };
    return result;
}

fn decode_B_type_instr(encoded_instruction: u32) DecodeError!B_Type_Instr {
    var result: B_Type_Instr = undefined;
    const funct3 = get_field(encoded_instruction, 12, 3);
    result.rs1 = get_field(encoded_instruction, 15, 5);
    result.rs2 = get_field(encoded_instruction, 20, 5);
    const imm11 = get_field(encoded_instruction, 7, 1);
    const imm4_1 = get_field(encoded_instruction, 8, 4);
    const imm10_5 = get_field(encoded_instruction, 25, 6);
    const imm12 = get_field(encoded_instruction, 31, 1);
    result.imm = sext((imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1), 13);
    result.function = switch (funct3) {
        0b000 => .Beq,
        0b001 => .Bne,
        0b100 => .Blt,
        0b101 => .Bge,
        0b110 => .Bltu,
        0b111 => .Bgeu,
        else => return DecodeError.UnknownInstruction,
    };
    return result;
}

fn decode_R_type_instr(encoded_instruction: u32) DecodeError!R_Type_Instr {
    var result: R_Type_Instr = undefined;
    const funct3 = get_field(encoded_instruction, 12, 3);
    const funct7 = get_field(encoded_instruction, 25, 7);
    result.rd = get_field(encoded_instruction, 7, 5);
    result.rs1 = get_field(encoded_instruction, 15, 5);
    result.rs2 = get_field(encoded_instruction, 20, 5);
    result.function = switch (funct3) {
        0 => switch (funct7) {
            0b0000000 => .Add,
            0b0100000 => .Sub,
            else => return DecodeError.UnknownInstruction,
        },
        0b001 => .Sll,
        0b010 => .Slt,
        0b011 => .Sltu,
        0b100 => .Xor,
        0b101 => switch (funct7) {
            0b0000000 => .Srl,
            0b0100000 => .Sra,
            else => return DecodeError.UnknownInstruction,
        },
        0b110 => .Or,
        0b111 => .And,
        else => return DecodeError.UnknownInstruction,
    };
    return result;
}

fn get_field(encoded_instruction: u32, start: u5, size: u5) u32 {
    return (encoded_instruction >> start) & ((@as(u32, 1) << size) - 1);
}

test "Decode I-type" {
    const raw_instruction = 0xff610093;
    const decoded = try decode_I_type_instr(raw_instruction);
    try std.testing.expectEqual(decoded, I_Type_Instr{
        .function = .Addi,
        .rd = 1,
        .rs1 = 2,
        .imm = @bitCast(@as(i32, -10)),
    });
}

test "Decode R-type" {
    const raw_instruction = 0x40008133;
    const decoded = try decode_R_type_instr(raw_instruction);
    try std.testing.expectEqual(decoded, R_Type_Instr{
        .function = .Sub,
        .rd = 2,
        .rs1 = 1,
        .rs2 = 0,
    });
}
