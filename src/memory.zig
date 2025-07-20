const std = @import("std");
const Allocator = std.mem.Allocator;

const OpCode = @import("common.zig").OpCode;

pub fn growCapacity(c: usize) usize {
    return if (c < 8) 8 else c * 2;
}

pub fn panicMem(comptime msg: []const u8, err: Allocator.Error) noreturn {
    std.debug.panic("Error {d} dynamic array: {}", .{ msg, err });
}

pub fn panicReallocating(err: Allocator.Error) noreturn {
    panicMem("reallocating", err);
}
pub fn panicAllocating(err: Allocator.Error) noreturn {
    panicMem("allocating", err);
}

pub fn growArray(allocator: Allocator, array: []OpCode, newCount: usize) []OpCode {
    return allocator.realloc(array, newCount) catch |err| panicReallocating(err);
}
