const std = @import("std");

const Cpu = @import("./core/cpu.zig").Cpu;
const Memory = @import("./core/memory.zig").Memory;

const boot_code = @embedFile("./boot/boot.bin");
pub fn main() !void {
    var cpu: Cpu = .{};
    std.mem.copyForwards(u8, &cpu.memory.rom, boot_code);
    _ = cpu.run() catch |e| {
        std.log.err("cpu failed with {any}", .{e});
    };
}
