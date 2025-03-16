const std = @import("std");

const instructions = @import("instructions.zig");
const Instruction = @import("instructions.zig").Instruction;
const sext = @import("instructions.zig").sext;
const zext = @import("instructions.zig").zext;
const Memory = @import("memory.zig").Memory;
const CSR = @import("csr.zig").CSR;

// Contains the code to execute instructions and wrappers for fetch and decode
// This can be considered the entry point of the library.

//The number here is the bits stored in mstatus for previous priviledge
pub const Privilege = enum(u8) {
    Machine = 0b00,
    Supervisor = 0b01,
    User = 0b10,
};

//Order matters here, the cause is used as an offset into the vector table
pub const TrapCause = enum(u32) {
    InstructionAddressMisaligned,
    InstructionAccessFault,
    IllegalInstruction,
    Breakpoint,
    LoadAddressMisaligned,
    LoadAccessFault,
    StoreAddressMisaligned,
    StoreAccessFault,
    EnvironmentCallFromUMode,
    EnvironmentCallFromSMode,
    Reserved10,
    EnvironmentCallFromMMode,
    InstructionPageFault,
    LoadPageFault,
    Reserved14,
    StorePageFault,

    //Interupts (have an extra bit set indicating interupt hence the or)
    UserSoftwareInterrupt = 0x80000000 | 0,
    SupervisorSoftwareInterrupt = 0x80000000 | 1,
    ReservedSoftInt2 = 0x80000000 | 2,
    MachineSoftwareInterrupt = 0x80000000 | 3,
    UserTimerInterrupt = 0x80000000 | 4,
    SupervisorTimerInterrupt = 0x80000000 | 5,
    ReservedTimerInt6 = 0x80000000 | 6,
    MachineTimerInterrupt = 0x80000000 | 7,
    UserExternalInterrupt = 0x80000000 | 8,
    SupervisorExternalInterrupt = 0x80000000 | 9,
    ReservedExtInt10 = 0x80000000 | 10,
    MachineExternalInterrupt = 0x80000000 | 11,
};

pub const Cpu = struct {
    const Self = @This();

    const DefaultPC = Memory.RomStart + Memory.VecTableSize; //_start is placed after vector table by linker

    memory: Memory = Memory{},
    csr: CSR = CSR{},
    registers: [32]u32 = [_]u32{0} ** 32,
    pc: u32 = DefaultPC,
    current_privilege: Privilege = .Machine,

    pub fn reset(self: *Self) void {
        self.registers = [_]u32{0} ** 32;
        self.pc = DefaultPC;
        self.csr.write_mstatus(.Mie, 1); //enable interupts
    }

    pub fn run(self: *Self) !void {
        main_loop: while (true) {
            const encoded_instruction = self.fetch() catch {
                self.trap(.InstructionAccessFault);
                continue :main_loop;
            };
            const decoded_instruction = self.decode(encoded_instruction) catch {
                self.trap(.IllegalInstruction);
                continue :main_loop;
            };
            self.execute(decoded_instruction) catch |e| {
                switch (e) {
                    CSR.CSRError.NotAllowed => self.trap(.IllegalInstruction),
                    Memory.MemoryError.LoadNotAllowed => self.trap(.LoadAccessFault),
                    Memory.MemoryError.LoadUnaligned => self.trap(.LoadAddressMisaligned),
                    Memory.MemoryError.LoadOutOfBounds => self.trap(.LoadAccessFault),
                    Memory.MemoryError.StoreNotAllowed => self.trap(.StoreAccessFault),
                    Memory.MemoryError.StoreUnaligned => self.trap(.StoreAddressMisaligned),
                    Memory.MemoryError.StoreOutOfBounds => self.trap(.StoreAccessFault),
                }
                continue :main_loop;
            };
        }
    }

    //for debugging
    pub fn run_step_through(self: *Self) !void {
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

    pub fn trap(self: *Self, cause: TrapCause) void {
        //save the old pc so we can return, and set the cause so we jump to the right handler
        const cause_num = @intFromEnum(cause);
        self.csr.mepc = self.pc;
        self.csr.mcause = cause_num;

        //save mstatus fields right now this is kinda useless for us but it makes it more spec compliant
        self.csr.write_mstatus(.Mpp, @intFromEnum(self.current_privilege));
        self.csr.write_mstatus(.Mpie, self.csr.read_mstatus(.Mie));
        self.csr.write_mstatus(.Mie, 0);

        const isInterrupt = cause_num & 0x8000_0000 == 1; //interupt has a special bit set
        if (!isInterrupt) {
            const index = cause_num & 0x7fff_ffff;
            self.pc = (self.csr.mtvec & 0xfffffffc) + (index * 4);
        } else {
            self.pc = self.csr.mtvec; //we dont really have interupt handlers so this is placeholder
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
                    .Mul => self.register_write(inst.rd, self.registers[inst.rs1] *% self.registers[inst.rs2]),
                    .Mulh, .Mulhsu => {
                        const result: i64 = @as(i64, self.registers[inst.rs1]) *% @as(i64, self.registers[inst.rs2]);
                        self.register_write(inst.rd, @truncate(@as(u64, @bitCast(result)) >> 32));
                    },
                    .Mulhu => {
                        const result: u64 = @as(u64, self.registers[inst.rs1]) *% @as(u64, self.registers[inst.rs2]);
                        self.register_write(inst.rd, @truncate(result >> 32));
                    },
                    .Div => {
                        if (self.registers[inst.rs2] == 0) {
                            self.register_write(inst.rd, @bitCast(@as(i32, -1)));
                        } //division by zero returns -1
                        else if (self.registers[inst.rs1] == std.math.minInt(i32) and self.registers[inst.rs2] == @as(u32, @bitCast(@as(i32, -1)))) {
                            self.register_write(inst.rd, self.registers[inst.rs1]);
                        } // Handle overflow case
                        else {
                            const result: i32 = @divExact(@as(i32, @bitCast(self.registers[inst.rs1])), @as(i32, @bitCast(self.registers[inst.rs2])));
                            self.register_write(inst.rd, @bitCast(result));
                        }
                    },
                    .Divu => {
                        if (self.registers[inst.rs2] == 0) { //return max int if div by 0
                            self.register_write(inst.rd, std.math.maxInt(u32));
                        } else {
                            self.register_write(inst.rd, @divExact(self.registers[inst.rs1], self.registers[inst.rs2]));
                        }
                    },
                    .Rem => {
                        if (self.registers[inst.rs2] == 0) {
                            self.register_write(inst.rd, self.registers[inst.rs1]); // Remainder by zero returns rs1 (per spec)
                        } else if (@as(i32, @bitCast(self.registers[inst.rs1])) == std.math.minInt(i32) and self.registers[inst.rs2] == @as(u32, @bitCast(@as(i32, -1)))) {
                            self.register_write(inst.rd, 0);
                        } else {
                            self.register_write(inst.rd, @bitCast(@rem(@as(i32, @bitCast(self.registers[inst.rs1])), @as(i32, @bitCast(self.registers[inst.rs2])))));
                        }
                    },
                    .Remu => {
                        if (self.registers[inst.rs2] == 0) {
                            self.register_write(inst.rd, self.registers[inst.rs1]); // Remainder by zero returns rs1 (per spec)
                        } else {
                            self.register_write(inst.rd, @rem(self.registers[inst.rs1], self.registers[inst.rs2]));
                        }
                    },
                    else => unreachable,
                }
            },
            .I_type => |inst| {
                //this computation can overflow the bounds because rs1 is not actually a register for some Itype
                //there are better ways of doing this
                const value = if (inst.function != .Mret) inst.imm +% self.registers[inst.rs1] else 0;
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
                    .Ebreak => {
                        std.log.debug("---------------Ebreak--------------\n", .{});
                        std.log.debug("pc: 0x{x}", .{self.pc});
                        std.log.debug("registers: {any}", .{self.registers});
                        std.log.debug("csrs: mcause: {s}, mepc: 0x{x}, mtvec: {d}, mtval: {d}", .{
                            @tagName(@as(TrapCause, @enumFromInt(self.csr.mcause))),
                            self.csr.mepc,
                            self.csr.mtvec,
                            self.csr.mtval,
                        });
                        std.log.debug("mstatus: mpp: {s}, mie: {d}, mpie: {d}\n", .{
                            @tagName(@as(Privilege, @enumFromInt(self.csr.read_mstatus(.Mpp)))),
                            self.csr.read_mstatus(.Mie),
                            self.csr.read_mstatus(.Mpie),
                        });
                        std.log.debug("--------------EndEbreak------------", .{});
                    },
                    .Ecall => {
                        switch (self.current_privilege) {
                            .Machine => self.trap(.EnvironmentCallFromMMode),
                            .Supervisor => self.trap(.EnvironmentCallFromSMode),
                            .User => self.trap(.EnvironmentCallFromUMode),
                        }
                    },
                    .Mret => {
                        self.pc = self.csr.mepc;
                        self.current_privilege = @enumFromInt(self.csr.read_mstatus(.Mpp));
                        self.csr.write_mstatus(.Mie, self.csr.read_mstatus(.Mpie));
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
                //the - 4 is because the PC is already pointing at the next instruction
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
