const std = @import("std");

const common = @import("common.zig");
const compiler = @import("compiler.zig");
const Chunk = common.Chunk;
const OpCode = common.OpCode;
const debug = @import("debug.zig");
const value = @import("value.zig");
const Value = value.Value;

pub const InterpretResult = enum { OK, COMPILE_ERR, RUNTIME_ERR };

const STACK_MAX = 256;

pub const VM = struct {
    chunk: *Chunk,
    ip: [*]u8, // ptr to next instruction to execute
    stack: [STACK_MAX]Value,
    stackTop: [*]Value,
    pub fn new() VM {
        return VM{ .chunk = undefined, .ip = undefined, .stack = undefined, .stackTop = undefined };
    }
    pub fn init(self: *VM) void {
        self.resetStack();
    }
    pub fn resetStack(self: *VM) void {
        self.stackTop = &self.stack;
    }
    pub fn free(self: *VM) void {
        _ = self;
    }
    pub fn runFile(self: *VM, allocator: std.mem.Allocator, filename: []u8) !void {
        const source: []const u8 = readFile(allocator, filename);
        defer allocator.free(source);

        switch (self.interpret(&source)) {
            .COMPILE_ERR => std.process.exit(65),
            .RUNTIME_ERR => std.process.exit(70),
            .OK => {},
        }
    }
    pub fn repl(self: *VM, stdout: std.fs.File, stdin: std.fs.File) !void {
        const outWriter = stdout.writer();
        const inReader = stdin.reader();
        var lineBuff: [1024]u8 = undefined;
        try outWriter.writeAll("> ");
        while (try inReader.readUntilDelimiterOrEof(&lineBuff, '\n')) |lineSlice| {
            if (lineSlice.len == 0) {
                try outWriter.writeByte('\n');
                break;
            }
            try outWriter.writeAll("> ");
        }
        _ = self;
    }
    pub fn interpret(self: *VM, source: *const []const u8) InterpretResult {
        var mayChunk: ?Chunk = compiler.compile(source);
        if (mayChunk) |*chunk| {
            defer chunk.free();
            self.chunk = chunk;
            // TODO: is this correct?
            self.ip = self.chunk.code.items.ptr;
            return self.run();
        }
        return .COMPILE_ERR;
    }
    fn readByte(vm: *VM) OpCode {
        const old = vm.ip;
        vm.ip += 1;
        return @enumFromInt(old[0]);
    }
    fn readConstant(vm: *VM) f64 {
        return vm.chunk.constants.items[readByte(vm).toU8()];
    }
    pub fn run(self: *VM) InterpretResult {
        while (true) {
            if (comptime common.DEBUG_TRACE_EXECUTION) {
                std.debug.print("          ", .{});
                var slot: [*]Value = &self.stack;
                while (@intFromPtr(slot) < @intFromPtr(self.stackTop)) : (slot += 1) {
                    std.debug.print("[ ", .{});
                    value.printValue(slot[0]);
                    std.debug.print(" ]", .{});
                }
                std.debug.print("\n", .{});
                _ = debug.disassembleInstruction(self.chunk.*, @intFromPtr(self.ip) - @intFromPtr(self.chunk.code.items.ptr));
            }

            switch (readByte(self)) {
                .CONSTANT => {
                    const constant: Value = readConstant(self);
                    self.push(constant);
                },
                .ADD => self.binaryOP(add),
                .SUBSTRACT => self.binaryOP(sub),
                .MULTIPLY => self.binaryOP(mul),
                .DIVIDE => self.binaryOP(div),
                .NEGATE => self.push(-self.pop()),
                .RETURN => {
                    value.printValue(self.pop());
                    std.debug.print("\n", .{});
                    return .OK;
                },
                else => {
                    return .RUNTIME_ERR;
                },
            }
        }
    }
    pub fn push(self: *VM, val: Value) void {
        self.stackTop[0] = val;
        self.stackTop += 1;
    }

    pub fn pop(
        self: *VM,
    ) Value {
        self.stackTop -= 1;
        return self.stackTop[0];
    }

    fn binaryOP(self: *VM, comptime op: fn (f64, f64) f64) void {
        const b = self.pop();
        const a = self.pop();
        self.push(op(a, b));
    }
};

fn add(a: f64, b: f64) f64 {
    return a + b;
}
fn sub(a: f64, b: f64) f64 {
    return a - b;
}
fn mul(a: f64, b: f64) f64 {
    return a * b;
}
fn div(a: f64, b: f64) f64 {
    return a / b;
}

fn readFile(allocator: std.mem.Allocator, path: []const u8) []const u8 {
    return blk: {
        const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch |err| {
            break :blk err;
        };
        defer file.close();
        // TODO: get size file.stat() or file.metadata() ?

        // 1024B = 1Kib, 1024KiB = 1MiB
        const buffer: []const u8 = file.readToEndAlloc(allocator, 1024 ^ 2) catch |err| {
            break :blk err;
        };
        break :blk buffer;
    } catch |err| {
        const stderr = std.io.getStdErr();
        stderr.writer().print("Error while reading file '{s}': {}\n", .{ path, err }) catch {};
        std.process.exit(74);
    };
}
