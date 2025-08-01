const std = @import("std");

const common = @import("common.zig");
const compiler = @import("compiler.zig");
const Chunk = common.Chunk;
const OpCode = common.OpCode;
const debug = @import("debug.zig");
const value = @import("value.zig");
const Value = value.Value;
const object = @import("object.zig");
const Obj = object.Obj;
const ObjString = object.ObjString;
const memory = @import("memory.zig");

pub const InterpretResult = enum {
    OK,
    COMPILE_ERR,
    RUNTIME_ERR,
    fn isError(self: InterpretResult) bool {
        return switch (self) {
            .OK => false,
            else => true,
        };
    }
};

const STACK_MAX = 256;

pub const VM = struct {
    allocator: std.mem.Allocator,
    chunk: *Chunk,
    ip: [*]u8, // ptr to next instruction to execute
    stack: [STACK_MAX]Value,
    stackTop: [*]Value,
    objects: ?*Obj,
    pub fn new(allocator: std.mem.Allocator) VM {
        return VM{ .allocator = allocator, .chunk = undefined, .ip = undefined, .stack = undefined, .stackTop = undefined, .objects = null };
    }
    pub fn init(self: *VM) void {
        self.resetStack();
        self.objects = null;
    }
    fn resetStack(self: *VM) void {
        self.stackTop = &self.stack;
    }
    pub fn free(self: *VM) void {
        self.freeObjects();
    }

    fn freeObjects(self: *VM) void {
        var maybeObject = self.objects;
        while (maybeObject) |obj| {
            const next = obj.next;
            obj.free(self.allocator);
            maybeObject = next;
        }
    }

    pub fn runFile(self: *VM, filename: []u8) !void {
        const source: []const u8 = readFile(self.allocator, filename);
        defer self.allocator.free(source);

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
            _ = self.interpret(&lineSlice);
            try outWriter.writeAll("> ");
        }
    }
    pub fn interpret(self: *VM, source: *const []const u8) InterpretResult {
        var compParser = compiler.Parser.new(self, source);
        // chunk is freed after its supposed to be run
        defer compParser.free();

        var mayChunk: ?Chunk = compParser.compile();

        if (mayChunk) |*chunk| {
            self.chunk = chunk;
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
    fn readConstant(vm: *VM) Value {
        return vm.chunk.constants.items[readByte(vm).toU8()];
    }
    pub fn run(self: *VM) InterpretResult {
        std.debug.print("\n== run() ==", .{});
        defer std.debug.print("\n", .{});
        while (true) {
            if (comptime common.DEBUG_TRACE_EXECUTION) {
                std.debug.print("          ", .{});
                var slot: [*]Value = &self.stack;
                while (@intFromPtr(slot) < @intFromPtr(self.stackTop)) : (slot += 1) {
                    std.debug.print("[ ", .{});
                    slot[0].print();
                    std.debug.print(" ]", .{});
                }
                std.debug.print("\n", .{});
            }

            switch (readByte(self)) {
                .CONSTANT => {
                    const constant: Value = readConstant(self);
                    self.push(constant);
                },
                .NIL => self.push(Value.nilVal()),
                .TRUE => self.push(Value.boolVal(true)),
                .FALSE => self.push(Value.boolVal(false)),
                .EQUAL => {
                    const b = self.pop();
                    const a = self.pop();
                    self.push(Value.boolVal(a.equal(b)));
                },
                .GREATER => if (self.binaryOP(bool, Value.boolVal, gt)) |v| return v else {},
                .LESS => if (self.binaryOP(bool, Value.boolVal, lt)) |v| return v else {},
                .ADD => {
                    if (self.peek(0).isString() and self.peek(1).isString()) {
                        self.concatenate();
                    } else if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                        const b = self.pop().number;
                        const a = self.pop().number;
                        self.push(Value.numberVal(a + b));
                    } else {
                        self.runtimeError("Operands must be two numbers or two strings", .{});
                        return .RUNTIME_ERR;
                    }
                },
                .SUBSTRACT => if (self.binaryOP(f64, Value.numberVal, sub)) |v| return v else {},
                .MULTIPLY => if (self.binaryOP(f64, Value.numberVal, mul)) |v| return v else {},
                .DIVIDE => if (self.binaryOP(f64, Value.numberVal, div)) |v| return v else {},
                .NOT => self.push(Value.boolVal(self.pop().isFalsey())),
                .NEGATE => {
                    switch (self.peek(0)) {
                        .number => self.push(Value.numberVal(-self.pop().number)),
                        else => {
                            self.runtimeError("Operand must be a number.", .{});
                            return .RUNTIME_ERR;
                        },
                    }
                },
                .RETURN => {
                    self.pop().print();
                    std.debug.print("\n", .{});
                    return .OK;
                },
                else => {
                    return .RUNTIME_ERR;
                },
            }
        }
    }
    fn peek(self: *VM, distance: u32) Value {
        return (self.stackTop - 1 - distance)[0];
    }
    fn push(self: *VM, val: Value) void {
        self.stackTop[0] = val;
        self.stackTop += 1;
    }

    fn pop(
        self: *VM,
    ) Value {
        self.stackTop -= 1;
        return self.stackTop[0];
    }

    fn binaryOP(self: *VM, comptime interT: type, comptime mkValue: fn (interT) Value, comptime op: fn (f64, f64) interT) ?InterpretResult {
        if (!self.peek(0).isNumber() or !self.peek(1).isNumber()) {
            self.runtimeError("Operands must be numbers.", .{});
            return .RUNTIME_ERR;
        }
        const b = self.pop().number;
        const a = self.pop().number;
        self.push(mkValue(op(a, b)));
        return null;
    }

    fn concatenate(self: *VM) void {
        const b = self.pop().obj.asObjString().str;
        const a = self.pop().obj.asObjString().str;

        const newStr = self.allocator.alloc(u8, a.len + b.len) catch |err| memory.panicMemAllocating("string", err);
        std.mem.copyForwards(u8, newStr, a);
        std.mem.copyForwards(u8, newStr[a.len..], b);

        self.push(Value.objVal(ObjString.allocateObjString(self, newStr).asObj()));
    }

    fn runtimeError(self: *VM, comptime format: []const u8, args: anytype) void {
        std.debug.print(format, args);
        std.debug.print("\n", .{});
        const instruction = self.ip - self.chunk.code.items.ptr - 1;
        const line = self.chunk.lines.items[instruction];
        std.debug.print("[line {}] in script\n", .{line});
        self.resetStack();
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

fn gt(a: f64, b: f64) bool {
    return a > b;
}
fn lt(a: f64, b: f64) bool {
    return a < b;
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
