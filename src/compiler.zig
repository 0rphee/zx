const std = @import("std");
const scanner = @import("scanner.zig");
const Scanner = scanner.Scanner;
const Token = scanner.Token;

pub fn compile(source: *const []const u8) []u8 {
    // _ = source;
    var scanner_inst = Scanner.new(source);
    var line: i32 = -1;
    while (true) {
        const token: Token = scanner_inst.scanToken();
        if (token.line != line) {
            std.debug.print("{d:<4}", .{token.line});
            line = token.line;
        } else {
            std.debug.print("   | ", .{});
        }
        std.debug.print("{d:<2} '{s}'\n", .{ token.line, token.slice });
        if (token.type == .EOF) break;
    }

    // TODO: FIX
    return undefined;
}
