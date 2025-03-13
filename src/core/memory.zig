const std = @import("std");
const root = @import("root");

const MemoryError = error{
    OutOfBounds,
    Unaligned,
    NotAllowed,
};

//I think this should do wrap-around as per the spec, but for debugging I want to error on out of bounds
pub const Memory = struct {
    const Self = @This();

    pub const RomSize = 0x2000;
    pub const RamSize = 0x800000;

    pub const RomStart = 0x10000000;
    pub const RamStart = RomStart + RomSize;

    //0xe4 & 0xe5 were chosen so i can easily recognize un-initialized memory
    rom: [RomSize]u8 = [_]u8{0xe4} ** RomSize,
    ram: [RamSize]u8 = [_]u8{0xe5} ** RamSize,

    pub fn read(self: *Self, comptime T: type, address: u32) MemoryError!T {
        if (address & 0b11 != 0) {
            return MemoryError.Unaligned;
        }
        if (address >= RomStart and address < RomStart + RomSize) {
            const addr = address - RomStart;
            return std.mem.readVarInt(T, self.rom[addr .. addr + @sizeOf(T)], .little);
        }
        if (address >= RamStart and address < RamStart + RamSize) {
            const addr = address - RamStart;
            return std.mem.readVarInt(T, self.ram[addr .. addr + @sizeOf(T)], .little);
        }
        std.log.err("Out of bounds read to {d}", .{address});
        return MemoryError.OutOfBounds;
    }

    pub fn write(self: *Self, comptime T: type, address: u32, value: T) MemoryError!void {
        if (address & 0b11 != 0) {
            return MemoryError.Unaligned;
        }
        if (address >= RomStart and address < RomStart + RomSize) {
            return MemoryError.NotAllowed;
        }
        if (address >= RamStart and address < RamStart + RamSize) {
            const addr = address - RamStart;
            var value_bytes: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &value_bytes, value, .little);
            for (0..value_bytes.len) |offset| {
                self.ram[addr + offset] = value_bytes[offset];
            }
            return;
        }
        std.log.err("Out of bounds write to {d}: start: {d}, end: {d}", .{ address, RamStart, RamStart + RamSize });
        return MemoryError.OutOfBounds;
    }
};

test "memory interface" {
    var mem = Memory{};

    try mem.write(u16, Memory.RamStart, 0x1234);
    const v = try mem.read(u8, Memory.RamStart);
    try std.testing.expect(v == 0x34);

    var err: MemoryError = undefined;
    mem.write(u32, Memory.RomStart, 100) catch |er| {
        err = er;
    };
    try std.testing.expect(err == MemoryError.NotAllowed);

    mem.write(u32, 0x0, 123) catch |er| {
        err = er;
    };
    try std.testing.expect(err == MemoryError.OutOfBounds);

    err = MemoryError.OutOfBounds;
    _ = mem.read(u16, Memory.RomStart + 1) catch |er| {
        err = er;
    };
    try std.testing.expect(err == MemoryError.Unaligned);
}
