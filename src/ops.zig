const std = @import("std");
const CalVM = @import("main.zig").CalVM;

const Opcode = enum(u8) {
    NOP,
    JMP,
    JNZ,
    JZ,
    ADD,
    SUB,
    MUL,
    IECALL,
    DIV,
    IDIV,
    MOD,
    IMOD,
    DUP,
    OVER,
    SWAP,
    EQU,
    NEQU,
    GTH,
    LTH,
    IGTH,
    ILTH,
    AND,
    OR,
    XOR,
    NOT,
    WRB,
    WRH,
    WRW,
    RDB,
    RDH,
    RDW,
    CALL,
    ECALL,
    RET,
    SHL,
    SHR,
    POP,
    HALT,
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
    }
}
