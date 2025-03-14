const std = @import("std");
const config = @import("config");

const Cpu = @import("./core/cpu.zig").Cpu;
const Memory = @import("./core/memory.zig").Memory;

const boot_code = @embedFile("bootbinary");
pub fn main() !void {
    var cpu: Cpu = .{};
    std.mem.copyForwards(u8, &cpu.memory.rom, boot_code);
    const run_func = if (config.cpu_step_through) Cpu.run_step_through else Cpu.run;
    _ = run_func(&cpu) catch |e| {
        std.log.err("cpu failed with {any}", .{e});
    };
}

test {
    @import("std").testing.refAllDecls(@This());
}
