//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const common = @import("common.zig");
const Chunk = common.Chunk;
const OpCode = common.OpCode;
const debug = @import("debug.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    std.debug.print("There are {d} args:\n", .{args.len});
    for (args) |arg| {
        std.debug.print("  {s}\n", .{arg});
    }

    // std.debug.print("\n\n\n", .{});
    // std.debug.print("sizeof [*]u8: {d}\n", .{@sizeOf([*]u8)});

    // var array: []u8 = try allocator.alloc(u8, 0);
    // std.debug.print("array.len: {}\n", .{array.len});
    // std.debug.print("array.ptr: {}\n", .{@intFromPtr(array.ptr)});
    // allocator.free(array);
    // array.len = 0;
    // array.ptr = null;
    // std.debug.print("array.len: {}\n", .{array.len});
    // std.debug.print("array.ptr: {}\n", .{@intFromPtr(array.ptr)});

    std.debug.print("Opcode size: {}\n", .{@sizeOf(OpCode)});

    var chunk: Chunk = Chunk.new(allocator);
    chunk.write(allocator, OpCode.OP_RETURN);
    debug.disassembleChunk(chunk, "test chunk");
    chunk.free(allocator);
    return 0;
}

test "simple test" {
    try std.testing.expect(true);
}
