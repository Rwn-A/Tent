const Privilege = @import("cpu.zig").Privilege;

const RomStart = @import("memory.zig").Memory.RomStart;

pub const CSR = struct {
    const Self = @This();

    pub const CSRError = error{
        NotAllowed,
    };

    mstatus: u32 = 0, // Machine Status Register
    mcause: u32 = 0, // Machine Cause Register
    mtvec: u32 = RomStart, // Machine Trap Vector Register
    mepc: u32 = 0, // Machine Exception Program Counter
    mtval: u32 = 0, // Machine Trap Value Register

    pub fn read_csr(self: *Self, privilege: Privilege, address: u32) CSRError!u32 {
        const csr_priv = (address >> 8) & 0b11;

        const can_read = switch (csr_priv) {
            0b11 => privilege == .Machine,
            0b10 => privilege == .Machine or privilege == .Supervisor,
            0b01 => true,
            else => unreachable,
        };

        if (!can_read) return CSRError.NotAllowed;

        switch (address) {
            0x300 => return self.mstatus,
            0x342 => return self.mcause,
            0x305 => return self.mtvec,
            0x341 => return self.mepc,
            0x343 => return self.mtval,
            else => return 0,
        }
    }

    pub fn write_csr(self: *Self, privilege: Privilege, address: u32, value: u32) CSRError!void {
        const csr_priv = (address >> 8) & 0b11;

        if (address >> 10 != 0) return CSRError.NotAllowed; //is write allowed

        const can_write = switch (csr_priv) {
            0b11 => privilege == .Machine,
            0b10 => privilege == .Machine or privilege == .Supervisor,
            0b01 => true,
            else => unreachable,
        };

        if (!can_write) return CSRError.NotAllowed;

        switch (address) {
            0x300 => self.mstatus = value,
            0x342 => self.mcause = value,
            0x305 => self.mtvec = value,
            0x341 => self.mepc = value,
            0x343 => self.mtval = value,
            else => return,
        }
    }

    //mstatus is finicky with lots of little fields these helper functions make it easier
    pub const MstatusFields = enum {
        Mpp,
        Mie,
        Mpie,
    };

    pub fn read_mstatus(self: *Self, field: CSR.MstatusFields) u32 {
        switch (field) {
            .Mpp => return (self.mstatus >> 11) & 0b11,
            .Mie => return (self.mstatus >> 3) & 0b1,
            .Mpie => return (self.mstatus >> 7) & 0b1,
        }
    }

    pub fn write_mstatus(self: *Self, field: CSR.MstatusFields, value: u32) void {
        const shift_amt: u5 = switch (field) {
            .Mpp => 11,
            .Mie => 3,
            .Mpie => 7,
        };
        const mask: u32 = switch (field) {
            .Mpp => @as(u32, 0b11) << shift_amt,
            .Mie => @as(u32, 0b1) << shift_amt,
            .Mpie => @as(u32, 0b1) << shift_amt,
        };
        self.mstatus &= ~mask;
        self.mstatus |= (value << shift_amt) & mask;
    }
};
