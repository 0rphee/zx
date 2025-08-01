const std = @import("std");
const Allocator = std.mem.Allocator;

const OpCode = @import("common.zig").OpCode;

pub fn panicMem(comptime action: []const u8, comptime allocatedObject: []const u8, err: Allocator.Error) noreturn {
    std.debug.panic("Error {s} {s}: {}", .{ action, allocatedObject, err });
}

pub fn panicMemAllocating(comptime allocatedObject: []const u8, err: Allocator.Error) noreturn {
    panicMem("allocating", allocatedObject, err);
}

pub fn panicMemDuplicating(comptime allocatedObject: []const u8, err: Allocator.Error) noreturn {
    panicMem("duplicating", allocatedObject, err);
}

pub fn panicMemArray(comptime action: []const u8, err: Allocator.Error) noreturn {
    panicMem(action, "dynamic array", err);
}

pub fn panicMemReallocatingArray(err: Allocator.Error) noreturn {
    panicMemArray("reallocating", err);
}
pub fn panicMemAllocatingArray(err: Allocator.Error) noreturn {
    panicMemArray("allocating", err);
}
