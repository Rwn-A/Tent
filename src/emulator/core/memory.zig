const std = @import("std");
const config = @import("config");

// Functions for reading and writing from memory, not a full fledged MMU at all.

//I think this should do wrap-around as per the spec, but for debugging I want to error on out of bounds
pub const Memory = struct {
    const Self = @This();

    //these constants are used to check where an address wants to read from
    pub const VecTableSize = config.vec_table_size;

    pub const RomSize = config.rom_size;
    pub const RamSize = config.ram_size;

    pub const RomStart = config.rom_start;
    pub const RamStart = config.ram_start;

    pub const MmioSize = config.mmio_size;
    pub const MmioStart = config.mmio_start;

    //load and store have different errors because they have a different mcause value
    pub const MemoryError = error{
        StoreOutOfBounds,
        StoreUnaligned,
        StoreNotAllowed,
        LoadOutOfBounds,
        LoadUnaligned,
        LoadNotAllowed,
    };

    //0xe4 & 0xe5 were chosen so i can easily recognize un-initialized memory
    rom: [RomSize]u8 = [_]u8{0xe4} ** RomSize,
    ram: [RamSize]u8 = [_]u8{0xe5} ** RamSize,

    fn address_in_range(address: u32, start: u32, size: u32) bool {
        return if (address >= start and address < start + size) true else false;
    }

    pub fn read(self: *Self, comptime T: type, address: u32) MemoryError!T {
        if ((address & (@alignOf(T) - 1)) != 0) {
            std.log.err("unaligned read to {d}", .{address});
            return MemoryError.LoadUnaligned;
        }
        if (address_in_range(address, RomStart, RomSize)) {
            const addr = address - RomStart;
            return std.mem.readVarInt(T, self.rom[addr .. addr + @sizeOf(T)], .little);
        }
        if (address_in_range(address, RamStart, RamSize)) {
            const addr = address - RamStart;
            return std.mem.readVarInt(T, self.ram[addr .. addr + @sizeOf(T)], .little);
        }
        if (address_in_range(address, MmioStart, MmioSize)) {
            var buf = [1]u8{0};
            _ = std.io.getStdIn().read(&buf) catch {};
            return @intCast(buf[0]);
        }
        std.log.err("Out of bounds read to {d}: start: {d}, end: {d}", .{ address, RamStart, RamStart + RamSize });
        return MemoryError.LoadOutOfBounds;
    }

    pub fn write(self: *Self, comptime T: type, address: u32, value: T) MemoryError!void {
        if ((address & (@alignOf(T) - 1)) != 0) {
            std.log.err("unaligned read to {d}", .{address});
            return MemoryError.StoreUnaligned;
        }
        if (address_in_range(address, RomStart, RomSize)) {
            return MemoryError.StoreNotAllowed;
        }
        if (address_in_range(address, RamStart, RamSize)) {
            const addr = address - RamStart;
            var value_bytes: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &value_bytes, value, .little);
            for (0..value_bytes.len) |offset| {
                self.ram[addr + offset] = value_bytes[offset];
            }
            return;
        }
        if (address_in_range(address, MmioStart, MmioSize)) {
            if (address == MmioStart) std.process.exit(@intCast(value)); //our way of exiting emulator for now
            std.debug.print("{any}\n", .{value});
            return;
        }

        std.log.err("Out of bounds write to {d}: start: {d}, end: {d}", .{ address, RamStart, RamStart + RamSize });
        return MemoryError.StoreOutOfBounds;
    }
};
