const std = @import("std");

const Stack = struct {
    buf: [256]u32 = undefined,
    ptr: u8 = 0,

    pub fn push(self: *Stack, val: u32) void {
        self.buf[self.ptr] = val;
        self.ptr += 1;
    }

    pub fn pop(self: *Stack) u32 {
        self.ptr -= 1;
        return self.buf[self.ptr];
    }
};

const max_int = std.math.maxInt(u32);

const ECall = struct {
    func: *const fn (ctx: *anyopaque, vm: *CalVM) anyerror!void,
    ctx: *anyopaque = undefined,
};

const BinHeader = packed struct {
    code_size: u32,
    data_size: u32,
};

pub const CalVM = struct {
    code: []u8,
    ram: []u8,

    running: bool = true,
    ip: u32 = 0,
    exit_code: u32 = 0,

    data_stack: Stack = .{},
    return_stack: Stack = .{},

    ecalls: std.ArrayList(ECall),
    ecall_names: std.StringHashMap(u32),

    fn init(allocator: std.mem.Allocator, code: []u8, data: []u8) !CalVM {
        const ram = try allocator.alloc(u8, 65536);
        @memcpy(ram[0..data.len], data);

        var ecalls = std.ArrayList(ECall).init(allocator);
        try ecalls.append(.{ .func = lookup });

        return .{
            .code = code,
            .ram = ram,
            .ecalls = ecalls,
            .ecall_names = std.StringHashMap(u32).init(allocator),
        };
    }

    pub fn read(self: *CalVM, comptime T: type) T {
        const val = std.mem.readInt(T, self.code[self.ip..][0..@sizeOf(T)], .little);
        self.ip += @sizeOf(T);
        return val;
    }

    pub fn lookup(_: *anyopaque, self: *CalVM) !void {
        const addr = self.data_stack.pop();
        const string_length = std.mem.readInt(u32, self.ram[addr..][0..4], .little);
        const ecall_name = self.ram[addr + 4 .. addr + 4 + string_length];
        const ecall_id = self.ecall_names.get(ecall_name) orelse max_int;
        if (ecall_id == max_int) {
            std.debug.print("ECall lookup {s} failed\n", .{ecall_name});
        }
        self.data_stack.push(ecall_id);
    }

    fn addECall(self: *CalVM, name: []const u8, func: ECall) !void {
        try self.ecalls.append(func);
        try self.ecall_names.put(name, @intCast(self.ecalls.items.len - 1));
    }

    pub fn runECall(self: *CalVM, id: u32) !void {
        if (id >= self.ecalls.items.len) {
            std.debug.print("ECall 0x{x} missing\n", .{id});
            return error.UnknownECall;
        }
        const ecall = self.ecalls.items[id];
        try ecall.func(ecall.ctx, self);
    }

    fn step(self: *CalVM) !void {
        return @import("ops.zig").step(self);
    }

    fn run(self: *CalVM) !void {
        while (self.running) {
            try self.step();
        }
    }
};

fn printChar(_: *anyopaque, vm: *CalVM) !void {
    const val = vm.data_stack.pop();
    _ = try std.io.getStdOut().write(&[_]u8{@truncate(val)});
}

fn printSignedInt(_: *anyopaque, vm: *CalVM) !void {
    const val = vm.data_stack.pop();
    const signed: i32 = @bitCast(val);
    _ = try std.io.getStdOut().writer().print("{}", .{signed});
}

fn printInt(_: *anyopaque, vm: *CalVM) !void {
    const val = vm.data_stack.pop();
    _ = try std.io.getStdOut().writer().print("{}", .{val});
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stderr = std.io.getStdErr().writer();

    const args = try std.process.argsAlloc(allocator);
    if (args.len < 2) {
        try stderr.print("Usage: {s} program.cvm\n", .{args[0]});
        std.process.exit(1);
    }

    const file = try std.fs.cwd().openFile(args[1], .{});
    const header = try file.reader().readStructEndian(BinHeader, .little);

    const code: []u8 = try allocator.alloc(u8, header.code_size);
    const code_bytes_read = try file.readAll(code);
    if (code_bytes_read != header.code_size) {
        try stderr.print("Invalid binary: code overrun\n", .{});
        std.process.exit(1);
    }

    const data: []u8 = try allocator.alloc(u8, header.data_size);
    const data_bytes_read = try file.readAll(data);
    if (data_bytes_read != header.data_size) {
        try stderr.print("Invalid binary: data overrun\n", .{});
        std.process.exit(1);
    }

    var vm = try CalVM.init(allocator, code, data);
    try vm.addECall("print_ch", .{ .func = printChar });
    try vm.addECall("print_int", .{ .func = printInt });
    try vm.addECall("print_int_s", .{ .func = printSignedInt });
    try vm.run();

    std.process.exit(@truncate(vm.exit_code));
}
