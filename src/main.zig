const std = @import("std");
const config = @import("config");

const Cpu = @import("./core/cpu.zig").Cpu;
const Memory = @import("./core/memory.zig").Memory;

const boot_code = @embedFile("boot");
pub fn main() !void {
    var cpu: Cpu = .{};
    std.mem.copyForwards(u8, &cpu.memory.rom, boot_code);
    _ = cpu.run() catch |e| {
        std.log.err("cpu failed with {any}", .{e});
    };
}

fn hang() void {
    const stdin = std.io.getStdIn().reader();
    var buffer: [1]u8 = undefined;
    _ = stdin.readAll(&buffer) catch {};
}
//cant get zig test to load the zig build config so this is the solution for now
fn test_clock_speed() !void {
    var cpu: Cpu = .{};
    std.mem.copyForwards(u8, &cpu.memory.rom, boot_code);

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
    const clock_speed: f64 = (1 / (@as(f64, @floatFromInt(dt_tot)) / @as(f64, @floatFromInt(dt_tot)))) * std.math.pow(f64, 10, 9);
    std.debug.print("{d}", .{clock_speed});
}

fn test_cpu_step_through() !void {
    var cpu: Cpu = .{};
    std.mem.copyForwards(u8, &cpu.memory.rom, boot_code);

    std.log.info("Starting CPU at 0x{x}\n", .{cpu.pc});
    while (true) {
        std.log.debug("Fetching from 0x{x}", .{cpu.pc});
        const encoded_instruction = try cpu.fetch();
        hang();
        std.log.debug("Decoding 0x{x}", .{encoded_instruction});
        const decoded_instruction = try cpu.decode(encoded_instruction);
        hang();
        std.log.debug("Executing {s}", .{decoded_instruction});
        try cpu.execute(decoded_instruction);
        hang();
    }
}
