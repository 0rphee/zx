const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const memory = @import("memory.zig");
const value = @import("value.zig");
const Value = value.Value;

pub const DEBUG_PRINT_CODE = true;
pub const DEBUG_TRACE_EXECUTION = true;

pub const OpCode = enum(u8) {
    CONSTANT,
    ADD,
    SUBSTRACT,
    MULTIPLY,
    DIVIDE,
    NOT,
    NEGATE,
    RETURN,
    NIL,
    TRUE,
    FALSE,
    EQUAL,
    GREATER,
    LESS,
    _,
    pub fn toU8(self: OpCode) u8 {
        return @intFromEnum(self);
    }
};

pub const Chunk = struct {
    // TODO: multiArrayList for .code and .lines?
    code: std.ArrayList(u8),
    lines: std.ArrayList(u32),
    constants: std.ArrayList(Value),
    pub fn new(allocator: Allocator) Chunk {
        return .{ .code = ArrayList(u8).init(allocator), .lines = ArrayList(u32).init(allocator), .constants = ArrayList(Value).init(allocator) };
    }
    pub fn free(self: *Chunk) void {
        self.code.clearAndFree();
        self.lines.clearAndFree();
        // TODO: original C doesn't free constants in equivalent function
        self.constants.clearAndFree();
    }
    pub fn write(self: *Chunk, byte: u8, line: u32) void {
        self.code.append(byte) catch |err| memory.panicReallocating(err);
        self.lines.append(line) catch |err| memory.panicReallocating(err);
    }
    pub fn addConstant(self: *Chunk, val: Value) usize {
        self.constants.append(val) catch |err| memory.panicReallocating(err);
        return self.constants.items.len - 1;
    }
};
