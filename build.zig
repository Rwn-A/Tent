const std = @import("std");

pub fn build(b: *std.Build) void {
    const ram_size = b.option(u32, "ramsize", "Amount in bytes of RAM") orelse 0x800000;
    const rom_size = b.option(u32, "romsize", "Amount in bytes of ROM") orelse 0x2000;
    const rom_start = b.option(u32, "romstart", "Address to start ROM") orelse 0x10000000;

    const options = b.addOptions();
    options.addOption(u32, "ram_size", ram_size);
    options.addOption(u32, "rom_size", rom_size);
    options.addOption(u32, "rom_start", rom_start);

    const exe = b.addExecutable(.{
        .name = "Tent",
        .root_source_file = b.path("src/main.zig"),
        .target = b.graph.host,
    });

    exe.root_module.addOptions("config", options);

    b.installArtifact(exe);
}
