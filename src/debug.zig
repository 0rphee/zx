const std = @import("std");

const common = @import("common.zig");
const Chunk = common.Chunk;
const OpCode = common.OpCode;
const value = @import("value.zig");

pub fn disassembleChunk(chunk: Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});
    var offset: usize = 0;
    while (offset < chunk.code.items.len) {
        offset = disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: Chunk, offset: usize) usize {
    std.debug.print("{d:0>4} ", .{offset});
    if (offset > 0 and chunk.lines.items[offset] == chunk.lines.items[offset - 1]) {
        std.debug.print("   | ", .{});
    } else {
        std.debug.print("{d:>4} ", .{chunk.lines.items[offset]});
    }
    const instruction: u8 = chunk.code.items[offset];
    const op: OpCode = @enumFromInt(instruction);
    return switch (op) {
        .CONSTANT => constantInstruction("CONSTANT", chunk, offset),
        .ADD => simpleInstruction("ADD", offset),
        .SUBSTRACT => simpleInstruction("SUBSTRACT", offset),
        .MULTIPLY => simpleInstruction("MULTIPLY", offset),
        .DIVIDE => simpleInstruction("DIVIDE", offset),
        .NEGATE => simpleInstruction("NEGATE", offset),
        .RETURN => simpleInstruction("RETURN", offset),
        else => ret: {
            std.debug.print("Unknown opcode {d:0>4}\n", .{instruction});
            break :ret offset + 1;
        },
    };
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, chunk: Chunk, offset: usize) usize {
    const constantIx: u8 = chunk.code.items[offset + 1];
    std.debug.print("{s:<16} {d:>4} '", .{ name, constantIx });
    value.printValue(chunk.constants.items[constantIx]);
    std.debug.print("'\n", .{});
    return offset + 2;
}
