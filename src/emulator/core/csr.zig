const Privilege = @import("cpu.zig").Privilege;

const RomStart = @import("memory.zig").Memory.RomStart;

const CSRError = error{
    NotAllowed,
};

pub const CSR = struct {
    const Self = @This();

    mstatus: u32 = 0, // Machine Status Register
    mcause: u32 = 0, // Machine Cause Register
    mtvec: u32 = RomStart + 16, // Machine Trap Vector Register
    mie: u32 = 0, // Machine Interrupt Enable Register
    mepc: u32 = 0, // Machine Exception Program Counter
    mtval: u32 = 0, // Machine Trap Value Register
    mip: u32 = 0, // Machine Interrupt Pending Register

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
            0x304 => return self.mie,
            0x341 => return self.mepc,
            0x343 => return self.mtval,
            0x344 => return self.mip,
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
            0x304 => self.mie = value,
            0x341 => self.mepc = value,
            0x343 => self.mtval = value,
            0x344 => self.mip = value,
            else => return,
        }
    }
};
