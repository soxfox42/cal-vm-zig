const std = @import("std");
const CalVM = @import("main.zig").CalVM;

const Opcode = enum(u8) {
    NOP = 0b00000000,
    JMP = 0b00000001,
    JNZ = 0b00000010,
    JZ = 0b00000011,
    ADD = 0b00000100,
    SUB = 0b00000101,
    MUL = 0b00000110,
    IECALL = 0b00000111,
    DIV = 0b00001000,
    IDIV = 0b00001001,
    MOD = 0b00001010,
    IMOD = 0b00001011,
    DUP = 0b00001100,
    OVER = 0b00001101,
    SWAP = 0b00001110,
    EQU = 0b00001111,
    NEQU = 0b00010000,
    GTH = 0b00010001,
    LTH = 0b00010010,
    IGTH = 0b00010011,
    ILTH = 0b00010100,
    AND = 0b00010101,
    OR = 0b00010110,
    XOR = 0b00010111,
    NOT = 0b00011000,
    WRB = 0b00011001,
    WRH = 0b00011010,
    WRW = 0b00011011,
    RDB = 0b00011100,
    RDH = 0b00011101,
    RDW = 0b00011110,
    CALL = 0b00011111,
    ECALL = 0b00100000,
    RET = 0b00100001,
    SHL = 0b00100010,
    SHR = 0b00100011,
    POP = 0b00100100,
    HALT = 0b00100101,
    RDSP = 0b00100110,
    WDSP = 0b00100111,
    RRSP = 0b00101000,
    WRSP = 0b00101001,
};
const max_int = std.math.maxInt(u32);

pub fn step(self: *CalVM) !void {
    const instruction = self.read(u8);
    const immediate = instruction & 0x80 != 0;
    const opcode: Opcode = @enumFromInt(instruction & 0x7f);

    // std.debug.print("{} {} {}\n", .{ opcode, immediate, @intFromEnum(opcode) });

    if (immediate) {
        // Immediate just means push the next word to the stack first.
        const val = self.read(u32);
        self.data_stack.push(val);
    }

    switch (opcode) {
        .NOP => {},
        .JMP => {
            const addr = self.data_stack.pop();
            self.ip = addr;
        },
        .JNZ => {
            const addr = self.data_stack.pop();
            const cond = self.data_stack.pop();
            if (cond != 0) {
                self.ip = addr;
            }
        },
        .JZ => {
            const addr = self.data_stack.pop();
            const cond = self.data_stack.pop();
            if (cond == 0) {
                self.ip = addr;
            }
        },
        .ADD => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(a +% b);
        },
        .SUB => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(a -% b);
        },
        .MUL => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(a *% b);
        },
        .DIV => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(@divTrunc(a, b));
        },
        .IDIV => {
            const b: i32 = @bitCast(self.data_stack.pop());
            const a: i32 = @bitCast(self.data_stack.pop());
            self.data_stack.push(@bitCast(@divTrunc(a, b)));
        },
        .MOD => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(@rem(a, b));
        },
        .IMOD => {
            const b: i32 = @bitCast(self.data_stack.pop());
            const a: i32 = @bitCast(self.data_stack.pop());
            self.data_stack.push(@bitCast(@rem(a, b)));
        },
        .DUP => {
            const a = self.data_stack.pop();
            self.data_stack.push(a);
            self.data_stack.push(a);
        },
        .OVER => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(a);
            self.data_stack.push(b);
            self.data_stack.push(a);
        },
        .SWAP => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(b);
            self.data_stack.push(a);
        },
        .EQU => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(if (a == b) max_int else 0);
        },
        .NEQU => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(if (a != b) max_int else 0);
        },
        .GTH => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(if (a > b) max_int else 0);
        },
        .LTH => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(if (a < b) max_int else 0);
        },
        .IGTH => {
            const b: i32 = @bitCast(self.data_stack.pop());
            const a: i32 = @bitCast(self.data_stack.pop());
            self.data_stack.push(if (a > b) max_int else 0);
        },
        .ILTH => {
            const b: i32 = @bitCast(self.data_stack.pop());
            const a: i32 = @bitCast(self.data_stack.pop());
            self.data_stack.push(if (a < b) max_int else 0);
        },
        .AND => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(a & b);
        },
        .OR => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(a | b);
        },
        .XOR => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(a ^ b);
        },
        .NOT => {
            const a = self.data_stack.pop();
            self.data_stack.push(~a);
        },
        .WRB => {
            const addr = self.data_stack.pop();
            const value = self.data_stack.pop();
            std.mem.writeInt(u8, self.ram[addr..][0..1], @truncate(value), .little);
        },
        .WRH => {
            const addr = self.data_stack.pop();
            const value = self.data_stack.pop();
            std.mem.writeInt(u16, self.ram[addr..][0..2], @truncate(value), .little);
        },
        .WRW => {
            const addr = self.data_stack.pop();
            const value = self.data_stack.pop();
            std.mem.writeInt(u32, self.ram[addr..][0..4], value, .little);
        },
        .RDB => {
            const addr = self.data_stack.pop();
            const value = std.mem.readInt(u8, self.ram[addr..][0..1], .little);
            self.data_stack.push(value);
        },
        .RDH => {
            const addr = self.data_stack.pop();
            const value = std.mem.readInt(u16, self.ram[addr..][0..2], .little);
            self.data_stack.push(value);
        },
        .RDW => {
            const addr = self.data_stack.pop();
            const value = std.mem.readInt(u32, self.ram[addr..][0..4], .little);
            self.data_stack.push(value);
        },
        .CALL => {
            self.return_stack.push(self.ip);
            self.ip = self.data_stack.pop();
        },
        .ECALL => {
            const ecall_id = self.data_stack.pop();
            try self.runECall(ecall_id);
        },
        .IECALL => {
            const addr = self.data_stack.pop();
            const ecall_id = std.mem.readInt(u32, self.ram[addr..][0..4], .little);
            try self.runECall(ecall_id);
        },
        .RET => {
            self.ip = self.return_stack.pop();
        },
        .SHL => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(a << @truncate(b));
        },
        .SHR => {
            const b = self.data_stack.pop();
            const a = self.data_stack.pop();
            self.data_stack.push(a >> @truncate(b));
        },
        .POP => {
            _ = self.data_stack.pop();
        },
        .HALT => {
            self.running = false;
            self.exit_code = if (immediate) self.data_stack.pop() else 0;
        },
        .RDSP => {
            self.data_stack.push(self.data_stack.ptr);
        },
        .WDSP => {
            const ptr = self.data_stack.pop();
            self.data_stack.ptr = ptr;
        },
        .RRSP => {
            self.data_stack.push(self.return_stack.ptr);
        },
        .WRSP => {
            const ptr = self.data_stack.pop();
            self.return_stack.ptr = ptr;
        },
    }
}
