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

const ECall = *const fn (vm: *CalVM) anyerror!void;

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

    // TODO: add a *anyopaque context to ecall definitions for stateful ecalls?
    // This could probably avoid the need for special-cased ecall 0.
    ecalls: std.ArrayList(ECall),
    ecall_names: std.StringHashMap(u32),

    fn init(allocator: std.mem.Allocator, code: []u8, data: []u8) !CalVM {
        const ram = try allocator.alloc(u8, 65536);
        @memcpy(ram[0..data.len], data);

        return .{
            .code = code,
            .ram = ram,
            .ecalls = std.ArrayList(ECall).init(allocator),
            .ecall_names = std.StringHashMap(u32).init(allocator),
        };
    }

    pub fn read(self: *CalVM, comptime T: type) T {
        const val = std.mem.readInt(T, self.code[self.ip..][0..@sizeOf(T)], .little);
        self.ip += @sizeOf(T);
        return val;
    }

    pub fn lookup(self: *CalVM) void {
        const addr = self.data_stack.pop();
        const string_length = std.mem.readInt(u32, self.ram[addr..][0..4], .little);
        const ecall_name = self.ram[addr + 4 .. addr + 4 + string_length];
        const ecall_id = self.ecall_names.get(ecall_name) orelse max_int;
        if (ecall_id == max_int) {
            std.debug.print("ECall lookup {s} failed\n", .{ecall_name});
        }
        self.data_stack.push(ecall_id);
    }

    pub fn ecall(self: *CalVM, id: u32) !void {
        if (id == 0) {
            self.lookup();
            return;
        }
        if (id > self.ecalls.items.len) {
            std.debug.print("ECall 0x{x} missing\n", .{id});
            return error.UnknownECall;
        }
        try self.ecalls.items[id - 1](self);
    }

    fn addECall(self: *CalVM, name: []const u8, func: ECall) !void {
        try self.ecalls.append(func);
        try self.ecall_names.put(name, @intCast(self.ecalls.items.len));
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

fn printChar(vm: *CalVM) !void {
    const val = vm.data_stack.pop();
    _ = try std.io.getStdOut().write(&[_]u8{@truncate(val)});
}

fn printSignedInt(vm: *CalVM) !void {
    const val = vm.data_stack.pop();
    const signed: i32 = @bitCast(val);
    _ = try std.io.getStdOut().writer().print("{}", .{signed});
}

fn printInt(vm: *CalVM) !void {
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
    try vm.addECall("print_ch", printChar);
    try vm.addECall("print_int", printInt);
    try vm.addECall("print_int_s", printSignedInt);
    try vm.run();

    if (vm.exit_code != 0) {
        try stderr.print("Exit code {}\n", .{vm.exit_code});
    }
    std.process.exit(@truncate(vm.exit_code));
}
