const std = @import("std");

pub fn build(b: *std.Build) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    //used to configure emulator and boot code linker script.
    //vec table implicitly starts at bottom of rom
    const ram_size = b.option(u32, "ramsize", "Amount in bytes of RAM") orelse 0x800000;
    const rom_size = b.option(u32, "romsize", "Amount in bytes of ROM") orelse 0x2000;
    const vec_table_size = b.option(u32, "vectbsize", "Size in bytes that the vector table will take up") orelse 0x100;
    const rom_start = b.option(u32, "romstart", "Address to start ROM") orelse 0x0;
    const cpu_step_through = b.option(bool, "step", "Waits for keyboard input CPU continues") orelse false;
    const ram_start = (rom_size + rom_start);
    const mmio_size = 0x10;
    const mmio_start = ram_size + ram_start;

    //allows for passing in custom binaries to load into emulator
    //must start at the rom_start to be executed.
    const boot_path: ?[]const u8 = b.option([]const u8, "bootpath", "Path to boot binary") orelse null;

    const options = b.addOptions();
    options.addOption(u32, "ram_size", ram_size);
    options.addOption(u32, "rom_size", rom_size);
    options.addOption(u32, "rom_start", rom_start);
    options.addOption(u32, "ram_start", ram_start);
    options.addOption(u32, "vec_table_size", vec_table_size);
    options.addOption(bool, "cpu_step_through", cpu_step_through);
    options.addOption(u32, "mmio_size", mmio_size);
    options.addOption(u32, "mmio_start", mmio_start);

    //the below code ensures a binary boot binary exists, either one is provided by the user
    //or it compiles the default one included with the project.
    const boot_file = if (boot_path) |path| blk: {
        break :blk b.addInstallFile(b.path(path), "boot.bin");
    } else blk: {
        //generate linker script, needs to be dynamic to adjust to changing ram/rom sizes and positions
        const linker_script_text = try linker_script(
            allocator,
            rom_start,
            rom_size,
            ram_start,
            ram_size,
            mmio_start,
            mmio_size,
            vec_table_size,
        );
        const generate_linker_script = b.addWriteFile("boot.ld", linker_script_text);
        const linker_script_path = generate_linker_script.getDirectory().path(b, generate_linker_script.files.items[0].sub_path);
        allocator.free(linker_script_text);

        const riscv_target = std.Target.Query{
            .cpu_arch = .riscv32,
            .os_tag = .freestanding,
            .abi = .none,
            .cpu_features_sub = std.Target.riscv.featureSet(&.{.c}),
        };

        //if not set to releaseSmall the code overuns the rom
        const bootloader = b.addExecutable(.{
            .name = "bootloader",
            .root_source_file = b.path("src/boot/boot.zig"),
            .target = b.resolveTargetQuery(riscv_target),
            .optimize = .ReleaseSmall,
            .strip = true,
            .link_libc = false,
            .single_threaded = true,
        });
        bootloader.bundle_compiler_rt = false;
        bootloader.no_builtin = true;

        //linker script must be present
        bootloader.step.dependOn(&generate_linker_script.step);

        //use the generated linker script
        bootloader.setLinkerScript(linker_script_path);

        //Convert bootloader to flat binary
        const objcopy = b.addObjCopy(bootloader.getEmittedBin(), .{
            .format = .bin,
        });
        const bootloader_bin = objcopy.getOutput();

        //install the flat binary
        const install_bin = b.addInstallFile(bootloader_bin, "boot.bin");
        break :blk install_bin;
    };

    //build emulator
    const emulator = b.addExecutable(.{
        .name = "tent",
        .root_source_file = b.path("src/emulator/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    emulator.step.dependOn(&boot_file.step); // Ensure binary is ready

    //replaces the @embedFile("bootbinary") in main.zig with the appropiate path
    emulator.root_module.addAnonymousImport("bootbinary", .{
        .root_source_file = boot_file.source,
    });

    //allows the emulator source code to access ram/rom information under the "config" import
    emulator.root_module.addOptions("config", options);

    //final install
    const emulator_artifact = b.addInstallArtifact(emulator, .{ .dest_dir = .{ .override = boot_file.dir } });
    b.getInstallStep().dependOn(&emulator_artifact.step);
    b.getInstallStep().dependOn(&boot_file.step);

    //allow us to run tests since the tests also depend on the binary and ram/rom info
    const test_step = b.step("test", "Runs all tests");
    const all_tests = b.addTest(.{
        .name = "tests",
        .root_source_file = b.path("src/emulator/main.zig"),
    });
    all_tests.step.dependOn(&emulator_artifact.step);
    all_tests.root_module.addAnonymousImport("bootbinary", .{
        .root_source_file = boot_file.source,
    });
    all_tests.root_module.addOptions("config", options);

    const run_test = b.addRunArtifact(all_tests);
    test_step.dependOn(&run_test.step);
}

//generate linker script for boot code
fn linker_script(
    allocator: std.mem.Allocator,
    rom_start: u32,
    rom_size: u32,
    ram_start: u32,
    ram_size: u32,
    mmio_start: u32,
    mmio_size: u32,
    vectsize: u32,
) ![]u8 {
    const fmt_str =
        \\ENTRY(_start)
        \\
        \\MEMORY
        \\{{
        \\    ROM (rx)  : ORIGIN = 0x{x}, LENGTH = 0x{x}
        \\    RAM (rw)  : ORIGIN =  0x{x}, LENGTH = 0x{x} 
        \\    MMIO_RESERVED (rw) : ORIGIN = 0x{x}, LENGTH = 0x{x}
        \\}}
        \\
        \\SECTIONS
        \\{{
        \\    .vect : {{
        \\         KEEP(*(.vect))
        \\          . = ALIGN(0x{x});
        \\      }} > ROM
        \\
        \\    .text : {{
        \\        *(.text._start)
        \\        *(.text)               
        \\    }} > ROM
        \\
        \\
        \\    /* Data Section (Initialized Data) */
        \\    .data : {{
        \\        *(.data)                
        \\    }} > RAM     
        \\
        \\    /* BSS Section (Uninitialized Data) */
        \\    .bss : {{
        \\        *(.bss)                 
        \\    }} > RAM
        \\
        \\    _end = .;
        \\
        \\    .mmio_reserved (NOLOAD) : {{
        \\      . = ALIGN(0x{x});   /* Align to MMIO size if needed */
        \\     }} > MMIO_RESERVED 
        \\    
        \\    /* End of memory region */
        \\    
        \\}}
        \\stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ;
    const text = try std.fmt.allocPrint(allocator, fmt_str, .{
        rom_start,
        rom_size,
        ram_start,
        ram_size,
        mmio_start,
        mmio_size,
        vectsize,
        mmio_size,
    });
    return text;
}
