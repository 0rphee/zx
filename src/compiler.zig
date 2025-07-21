const std = @import("std");

const common = @import("common.zig");
const Chunk = common.Chunk;
const scanner = @import("scanner.zig");
const Scanner = scanner.Scanner;
const Token = scanner.Token;

/// if `compile` returns null, the compilation failed
pub fn compile(source: *const []const u8) ?Chunk {
    var scanner_inst = Scanner.new(source);
    _ = scanner_inst.advance();
    _ = scanner_inst.expression();
    _ = scanner_inst.consume(.EOF, "Expect end of expression.");
    // TODO
    return null;
}
