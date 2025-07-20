const std = @import("std");
const Allocator = std.mem.Allocator;

const memory = @import("memory.zig");

pub const OpCode = enum(u8) { OP_RETURN };

pub const Chunk = struct {
    count: usize,
    // capacity is stored in the array (code.len)
    code: []OpCode,
    pub fn new(allocator: Allocator) Chunk {
        const code = allocator.alloc(OpCode, 0) catch |err| memory.panicAllocating(err);
        return .{
            .count = 0,
            .code = code,
        };
    }
    pub fn free(self: *Chunk, allocator: Allocator) void {
        allocator.free(self.code);
        self.count = 0;
        self.code = allocator.alloc(OpCode, 0) catch |err| memory.panicAllocating(err);
    }

    pub fn write(self: *Chunk, allocator: Allocator, byte: OpCode) void {
        if (self.code.len < self.count + 1) {
            // grow chunk
            const old_capacity = self.code.len;
            const newCapacity = memory.growCapacity(old_capacity);
            self.code = memory.growArray(allocator, self.code, newCapacity);
        }
        // add value
        self.code[self.count] = byte;
        self.count = self.count + 1;
    }
};
