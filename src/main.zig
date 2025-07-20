//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const common = @import("common.zig");
const Chunk = common.Chunk;
const OpCode = common.OpCode;
const debug = @import("debug.zig");
const vm = @import("vm.zig");
const VM = vm.VM;

pub fn main() !u8 {
    // const vm_: VM = VM.new();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // const args: [][:0]u8 = try std.process.argsAlloc(allocator);
    // defer std.process.argsFree(allocator, args);

    // std.debug.print("There are {d} args:\n", .{args.len});
    // for (args) |arg| {
    //     std.debug.print("  {s}\n", .{arg});
    // }

    std.debug.print("Opcode size: {}\n", .{@sizeOf(OpCode)});

    var chunk: Chunk = Chunk.new(allocator);
    const constant: u8 = @truncate(chunk.addConstant(1.2));
    chunk.write(OpCode.OP_CONSTANT.toU8(), 123);
    chunk.write(constant, 123);
    chunk.write(OpCode.OP_RETURN.toU8(), 123);

    debug.disassembleChunk(&chunk, "test chunk");
    _ = vm.VM.interpret(&chunk);
    chunk.free();
    return 0;
}

test "simple test" {
    try std.testing.expect(true);
}
