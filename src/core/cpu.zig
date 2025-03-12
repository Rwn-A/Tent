const std = @import("std");

const instructions = @import("instructions.zig");
const Instruction = @import("instructions.zig").Instruction;
const Memory = @import("memory.zig").Memory;

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
        std.log.info("Starting CPU at 0x{x}", .{self.pc});
        while (true) {
            std.log.debug("Fetching from 0x{x}", .{self.pc});
            const encoded_instruction = try self.fetch();
            std.log.debug("Fetched 0x{x}", .{encoded_instruction});
            const decoded_instruction = try self.decode(encoded_instruction);
            std.log.debug("Decoded instruction {s}", .{decoded_instruction});
            try self.execute(decoded_instruction);
        }
    }

    fn fetch(self: *Self) !u32 {
        defer self.pc += 4;
        return self.memory.read(u32, self.pc);
    }

    fn decode(self: *Self, encoded_instruction: u32) !Instruction {
        _ = self;
        return instructions.decode(encoded_instruction);
    }

    fn execute(self: *Self, inst: Instruction) !void {
        _ = self;
        switch (inst) {
            .R_type => {},
            .I_type => {},
        }
    }
};
