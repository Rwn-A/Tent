const std = @import("std");

const instructions = @import("instructions.zig");
const Instruction = @import("instructions.zig").Instruction;
const Memory = @import("memory.zig").Memory;

// Contains the code to execute instructions and wrappers for fetch and decode
// This can be considered the entry point of the library.

pub fn sext(value: u32, bits: u5) u32 {
    if (value & (@as(u32, 1) << (bits - 1)) != 0) {
        return value | ~((@as(u32, 1) << bits) - 1);
    }
    return value;
}

pub fn zext(value: u32, bits: u5) u32 {
    return value & ((@as(u32, 1) << bits) - 1);
}

pub const Cpu = struct {
    const Self = @This();

    memory: Memory = Memory{},
    registers: [32]u32 = [_]u32{0} ** 32,
    pc: u32 = Memory.RomStart,

    pub fn reset(self: *Self) void {
        self.registers = [_]u32{0} ** 32;
        self.pc = Memory.RomStart;
    }

    pub fn run(self: *Self) !void {
        var dt_tot: i128 = 0;
        var dt_count: i128 = 0;
        std.log.info("Starting CPU at 0x{x}\n", .{self.pc});
        while (true) {
            const t0 = std.time.nanoTimestamp();
            std.log.debug("Fetching from 0x{x}", .{self.pc});
            const encoded_instruction = try self.fetch();
            std.log.debug("Fetched 0x{x}", .{encoded_instruction});
            const decoded_instruction = try self.decode(encoded_instruction);
            std.log.debug("Decoded instruction {s}", .{decoded_instruction});
            try self.execute(decoded_instruction);
            std.log.debug("Executed instruction:\n    reg: {any}\n", .{self.registers});
            const t1 = std.time.nanoTimestamp();
            dt_tot += (t1 - t0);
            dt_count += 1;
            if (dt_count == 1000 * 1000) break;
        }
        std.debug.print("{d}", .{@divTrunc(dt_tot, dt_count)});
    }

    fn fetch(self: *Self) !u32 {
        defer self.pc += 4;
        return self.memory.read(u32, self.pc);
    }

    fn decode(self: *Self, encoded_instruction: u32) !Instruction {
        _ = self;
        return instructions.decode(encoded_instruction);
    }

    fn execute(self: *Self, inst_u: Instruction) !void {
        switch (inst_u) {
            .R_type => |inst| {
                switch (inst.function) {
                    .Add => self.register_write(inst.rd, self.registers[inst.rs1] +% self.registers[inst.rs2]),
                    .Sub => self.register_write(inst.rd, self.registers[inst.rs1] -% self.registers[inst.rs2]),
                    .Sll => self.register_write(inst.rd, self.registers[inst.rs1] << @as(u5, @truncate(self.registers[inst.rs2]))),
                    .Slt => {
                        const a: i32 = @bitCast(self.registers[inst.rs1]);
                        const b: i32 = @bitCast(self.registers[inst.rs2]);
                        self.register_write(inst.rd, if (a < b) 1 else 0);
                    },
                    .Sltu => self.register_write(inst.rd, if (self.registers[inst.rs1] < self.registers[inst.rs2]) 1 else 0),
                    .Xor => self.register_write(inst.rd, self.registers[inst.rs1] ^ self.registers[inst.rs2]),
                    .Or => self.register_write(inst.rd, self.registers[inst.rs1] | self.registers[inst.rs2]),
                    .And => self.register_write(inst.rd, self.registers[inst.rs1] & self.registers[inst.rs2]),
                    .Srl => self.register_write(inst.rd, self.registers[inst.rs1] >> @as(u5, @truncate(self.registers[inst.rs2]))),
                    .Sra => {
                        const a: u32 = @bitCast(self.registers[inst.rs1]);
                        const b: u32 = self.registers[inst.rs2];
                        if (@as(i32, @bitCast(a)) < 0) {
                            const shift_amount = @as(u5, @truncate((32 - b)));
                            self.register_write(inst.rd, (a >> @as(u5, @truncate(b))) | (@as(u32, 1) << shift_amount));
                        } else {
                            self.register_write(inst.rd, (a >> @as(u5, @truncate(b))));
                        }
                    },
                    else => unreachable,
                }
            },
            .I_type => |inst| {
                const value = inst.imm +% self.registers[inst.rs1];
                switch (inst.function) {
                    .Addi => self.register_write(inst.rd, value),
                    .Lw => self.register_write(inst.rd, try self.memory.read(u32, value)),
                    .Lh => self.register_write(inst.rd, sext(try self.memory.read(u16, value), 16)),
                    .Lhu => self.register_write(inst.rd, zext(try self.memory.read(u16, value), 16)),
                    .Lb => self.register_write(inst.rd, sext(try self.memory.read(u8, value), 8)),
                    .Lbu => self.register_write(inst.rd, zext(try self.memory.read(u8, value), 8)),
                    .Slti => {
                        const a: i32 = @bitCast(self.registers[inst.rs1]);
                        const b: i32 = @bitCast(inst.imm);
                        self.register_write(inst.rd, if (a < b) 1 else 0);
                    },
                    .Sltiu => self.register_write(inst.rd, if (self.registers[inst.rs1] < inst.imm) 1 else 0),
                    .Xori => self.register_write(inst.rd, self.registers[inst.rs1] ^ inst.imm),
                    .Ori => self.register_write(inst.rd, self.registers[inst.rs1] | inst.imm),
                    .Andi => self.register_write(inst.rd, self.registers[inst.rs1] & inst.imm),
                    .Ecall, .Ebreak => std.log.info("Tried to Ecall/Ebreak at 0x{x}", .{self.pc}),
                    .Jalr => {
                        self.register_write(inst.rd, self.pc);
                        self.pc = value & ~@as(u32, 1);
                    },
                    else => unreachable,
                }
            },
            .B_type => |inst| {
                const a: i32 = @bitCast(self.registers[inst.rs1]);
                const b: i32 = @bitCast(self.registers[inst.rs2]);
                switch (inst.function) {
                    .Blt => self.pc +%= if (a < b) inst.imm -% 4 else 0,
                    .Beq => self.pc +%= if (a == b) inst.imm -% 4 else 0,
                    .Bne => self.pc +%= if (a != b) inst.imm -% 4 else 0,
                    .Bge => self.pc +%= if (a >= b) inst.imm -% 4 else 0,
                    .Bltu => self.pc +%= if (self.registers[inst.rs1] < self.registers[inst.rs2]) inst.imm -% 4 else 0,
                    .Bgeu => self.pc +%= if (self.registers[inst.rs1] >= self.registers[inst.rs2]) inst.imm -% 4 else 0,
                    else => unreachable,
                }
            },
            .S_type => |inst| {
                switch (inst.function) {
                    .Sw => try self.memory.write(u32, self.registers[inst.rs1] +% inst.imm, self.registers[inst.rs2]),
                    .Sh => try self.memory.write(u16, self.registers[inst.rs1] +% inst.imm, @truncate(self.registers[inst.rs2])),
                    .Sb => try self.memory.write(u8, self.registers[inst.rs1] +% inst.imm, @truncate(self.registers[inst.rs2])),
                    else => unreachable,
                }
            },
            .J_type => |inst| {
                if (inst.function != .Jal) unreachable;
                self.register_write(inst.rd, self.pc);
                self.pc +%= ((inst.imm) -% 4);
            },
            .U_type => |inst| {
                switch (inst.function) {
                    .Lui => self.register_write(inst.rd, inst.imm << 12),
                    .Auipc => self.register_write(inst.rd, (self.pc -% 4) + (inst.imm << 12)),
                    else => unreachable,
                }
            },
        }
    }

    fn register_write(self: *Self, rd: u32, value: u32) void {
        if (rd == 0) return;
        self.registers[rd] = value;
    }
};

fn hang() void {
    const stdin = std.io.getStdIn().reader();
    var buffer: [1]u8 = undefined;
    _ = stdin.readAll(&buffer) catch {};
}
