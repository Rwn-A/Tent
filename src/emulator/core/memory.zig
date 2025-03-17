const std = @import("std");
const config = @import("config");

// Functions for reading and writing from memory, not a full fledged MMU at all.

//I think this should do wrap-around as per the spec, but for debugging I want to error on out of bounds
pub const Memory = struct {
    const Self = @This();

    //these constants are used to check where an address wants to read from
    pub const VecTableSize = config.memmap.vec_table_size;

    pub const RomSize = config.memmap.rom_size;
    pub const RamSize = config.memmap.ram_size;

    pub const RomStart = config.memmap.rom_start;
    pub const RamStart = config.memmap.ram_start;

    pub const MmioSize = config.memmap.mmio_size;
    pub const MmioStart = config.memmap.mmio_start;

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
            return self.mmio_read(T, address - MmioStart);
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
            return self.mmio_write(T, address - MmioStart, value);
        }

        std.log.err("Out of bounds write to {d}: start: {d}, end: {d}", .{ address, RamStart, RamStart + RamSize });
        return MemoryError.StoreOutOfBounds;
    }

    //seperate function to keep the read/write functions clean
    fn mmio_write(self: *Self, comptime T: type, offset: u32, value: T) MemoryError!void {
        _ = self;
        switch (offset) {
            0x0 => std.process.exit(@truncate(value)), //exit
            0x8 => std.debug.print("{c}", .{@as(u8, @truncate(value))}),
            else => return MemoryError.StoreNotAllowed,
        }
    }

    fn mmio_read(self: *Self, comptime T: type, offset: u32) MemoryError!T {
        switch (offset) {
            0x4 => return @truncate(self.load_kernel()),
            0x8 => {
                const stdin = std.io.getStdIn().reader();
                var buffer: [1]u8 = undefined;
                _ = stdin.readAll(&buffer) catch {};
                return buffer[0];
            },
            else => return MemoryError.StoreNotAllowed,
        }
    }

    const kernel_code = @embedFile("kernelbinary"); //replaced by zig build
    fn load_kernel(self: *Self) u32 {
        std.mem.copyForwards(u8, self.ram[config.memmap.kernel_ram_offset..], kernel_code);
        return Memory.RamStart + config.memmap.kernel_ram_offset;
    }
};
