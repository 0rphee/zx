//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const common = @import("common.zig");
const Chunk = common.Chunk;
const OpCode = common.OpCode;
const compiler = @import("compiler.zig");
const debug = @import("debug.zig");
const vm = @import("vm.zig");
const VM = vm.VM;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var vm_inst = vm.VM.new();
    vm_inst.init();
    defer vm_inst.free();

    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr().writer();

    const args: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    switch (args.len) {
        1 => try vm_inst.repl(stdout, stdin),
        2 => try vm_inst.runFile(allocator, args[1]),
        else => {
            try stderr.writeAll("Usage: zx [path]\n");
            std.process.exit(64);
        },
    }

    // std.debug.print("Opcode size: {}\n", .{@sizeOf(OpCode)});

    // var chunk: Chunk = Chunk.new(allocator);

    // const templine = 123;

    // chunk.write(OpCode.CONSTANT.toU8(), templine);
    // chunk.write(@truncate(chunk.addConstant(1.2)), templine);

    // chunk.write(OpCode.CONSTANT.toU8(), templine);
    // chunk.write(@truncate(chunk.addConstant(3.4)), templine);

    // chunk.write(OpCode.ADD.toU8(), templine);

    // chunk.write(OpCode.CONSTANT.toU8(), templine);
    // chunk.write(@truncate(chunk.addConstant(5.6)), templine);

    // chunk.write(OpCode.DIVIDE.toU8(), templine);

    // chunk.write(OpCode.NEGATE.toU8(), templine);
    // chunk.write(OpCode.RETURN.toU8(), templine);

    // debug.disassembleChunk(&chunk, "test chunk");
    // _ = vm.VM.interpret(&chunk);
    // chunk.free();
    return 0;
}

test "simple test" {
    try std.testing.expect(true);
}
