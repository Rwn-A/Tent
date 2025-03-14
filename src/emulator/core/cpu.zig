const std = @import("std");

const instructions = @import("instructions.zig");
const Instruction = @import("instructions.zig").Instruction;
const sext = @import("instructions.zig").sext;
const zext = @import("instructions.zig").zext;
const Memory = @import("memory.zig").Memory;
const CSR = @import("csr.zig").CSR;

// Contains the code to execute instructions and wrappers for fetch and decode
// This can be considered the entry point of the library.

pub const Privilege = enum {
    Machine,
    Supervisor,
    User,
};

pub const Cpu = struct {
    const Self = @This();

    memory: Memory = Memory{},
    csr: CSR = CSR{},
    registers: [32]u32 = [_]u32{0} ** 32,
    pc: u32 = Memory.RomStart,
    current_privilege: Privilege = .Machine,

    pub fn reset(self: *Self) void {
        self.registers = [_]u32{0} ** 32;
        self.pc = Memory.RomStart;
    }

    pub fn run(self: *Self) !void {
        while (true) {
            const encoded_instruction = try self.fetch();
            const decoded_instruction = try self.decode(encoded_instruction);
            try self.execute(decoded_instruction);
        }
    }

    //for debugging
    pub fn run_step_through(self: *Self) !void {
        std.log.info("Starting CPU at 0x{x}\n", .{self.pc});
        while (true) {
            std.log.debug("Fetching from 0x{x}", .{self.pc});
            const encoded_instruction = try self.fetch();
            wait();
            std.log.debug("Decoding 0x{x}", .{encoded_instruction});
            const decoded_instruction = try self.decode(encoded_instruction);
            wait();
            std.log.debug("Executing {s}", .{decoded_instruction});
            try self.execute(decoded_instruction);
            wait();
        }
    }

    pub fn trap(self: *Self, cause: u32) void {
        self.csr.mepc = self.pc;
        self.csr.mcause = cause;
        const isInterrupt = cause & 0x8000_0000;
        if (isInterrupt == 0) {
            const index = cause & 0x7fff_ffff;
            self.pc = (self.csr.mtvec & 0xfffffffc) + (index * 4);
        } else {
            self.pc = self.csr.mtvec;
        }
        self.current_privilege = Privilege.Machine;
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
                    .Slli => self.register_write(inst.rd, self.registers[inst.rs1] << @as(u5, @truncate(inst.imm))),
                    .Srli => self.register_write(inst.rd, self.registers[inst.rs1] >> @as(u5, @truncate(inst.imm))),
                    .Srai => {
                        const a: u32 = @bitCast(self.registers[inst.rs1]);
                        const b: u32 = inst.imm;
                        if (@as(i32, @bitCast(a)) < 0) {
                            const shift_amount = @as(u5, @truncate((32 - b)));
                            self.register_write(inst.rd, (a >> @as(u5, @truncate(b))) | (@as(u32, 1) << shift_amount));
                        } else {
                            self.register_write(inst.rd, (a >> @as(u5, @truncate(b))));
                        }
                    },
                    .Xori => self.register_write(inst.rd, self.registers[inst.rs1] ^ inst.imm),
                    .Ori => self.register_write(inst.rd, self.registers[inst.rs1] | inst.imm),
                    .Andi => self.register_write(inst.rd, self.registers[inst.rs1] & inst.imm),
                    .Ebreak => std.log.info("Tried to Ebreak at 0x{x}", .{self.pc}),
                    .Ecall => {
                        switch (self.current_privilege) {
                            .Machine => self.trap(11),
                            .Supervisor => self.trap(9),
                            .User => self.trap(8),
                        }
                    },
                    .Jalr => {
                        self.register_write(inst.rd, self.pc);
                        self.pc = value & ~@as(u32, 1);
                    },
                    .Csrrw, .Csrrwi => {
                        const val = if (inst.function == .Csrrwi) inst.rs1 else self.registers[inst.rs1];
                        if (inst.rd != 0) { //not supposed to read if rd is 0
                            self.register_write(inst.rd, try self.csr.read_csr(self.current_privilege, inst.imm));
                        }
                        try self.csr.write_csr(self.current_privilege, inst.imm, val);
                    }, //for csrrs and csrrc if rs1 is 0 it is supposed to read but not write
                    .Csrrs, .Csrrsi => blk: {
                        const val = if (inst.function == .Csrrsi) inst.rs1 else self.registers[inst.rs1];
                        const csr_old = try self.csr.read_csr(self.current_privilege, inst.imm);
                        self.register_write(inst.rd, csr_old);
                        if (inst.rs1 == 0) break :blk;
                        try self.csr.write_csr(self.current_privilege, inst.imm, csr_old | val);
                    },
                    .Csrrc, .Csrrci => blk: {
                        const val = if (inst.function == .Csrrci) inst.rs1 else self.registers[inst.rs1];
                        const csr_old = try self.csr.read_csr(self.current_privilege, inst.imm);
                        self.register_write(inst.rd, csr_old);
                        if (inst.rs1 == 0) break :blk;
                        try self.csr.write_csr(self.current_privilege, inst.imm, csr_old & ~val);
                    }, //for all these i instructions rs1 is actually an immediate.
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

//for debugging, used to step through the cpu execution
fn wait() void {
    const stdin = std.io.getStdIn().reader();
    var buffer: [1]u8 = undefined;
    _ = stdin.readAll(&buffer) catch {};
}

test "clock speed" {
    const code = @embedFile("bootbinary");
    var cpu: Cpu = .{};
    std.mem.copyForwards(u8, &cpu.memory.rom, code);

    var dt_tot: i128 = 0;
    var dt_count: i128 = 0;
    const max_iter = 1000 * 1000;
    while (true) {
        const t0 = std.time.nanoTimestamp();

        const encoded_instruction = try cpu.fetch();
        const decoded_instruction = try cpu.decode(encoded_instruction);
        try cpu.execute(decoded_instruction);

        const t1 = std.time.nanoTimestamp();
        dt_tot += (t1 - t0);
        dt_count += 1;

        if (dt_count == max_iter) break;
    }
    const clock_speed: f64 = (1 / (@as(f64, @floatFromInt(dt_tot)) / @as(f64, @floatFromInt(dt_count))));
    std.debug.print("{d:.6}GHz", .{clock_speed});
}
