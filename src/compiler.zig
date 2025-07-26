const std = @import("std");

const common = @import("common.zig");
const Chunk = common.Chunk;
const OpCode = common.OpCode;
const debug = @import("debug.zig");
const scanner = @import("scanner.zig");
const Scanner = scanner.Scanner;
const Token = scanner.Token;
const TokenType = scanner.TokenType;
const value = @import("value.zig");
const Value = value.Value;

pub const Parser = struct {
    current: Token,
    previous: Token,
    scanner: Scanner,
    hadError: bool,
    panicMode: bool,
    compilingChunk: Chunk,
    pub fn new(allocator: std.mem.Allocator, source: *const []const u8) Parser {
        return Parser{
            .current = undefined,
            .previous = undefined,
            .scanner = Scanner.new(source),
            .hadError = false,
            .panicMode = false,
            .compilingChunk = Chunk.new(allocator),
        };
    }

    pub fn free(self: *Parser) void {
        self.compilingChunk.free();
    }

    /// if `compile` returns null, the compilation failed
    /// compile assumes an already provided source
    pub fn compile(self: *Parser) ?Chunk {
        self.advance();
        self.expression();
        self.consume(.EOF, "Expect end of expression.");
        self.endCompiler();
        return if (self.hadError) null else self.compilingChunk;
    }

    fn endCompiler(self: *Parser) void {
        self.emitReturn();
        if (common.DEBUG_PRINT_CODE and !self.hadError) {
            debug.disassembleChunk(self.compilingChunk, "code");
        }
    }

    fn emitReturn(self: *Parser) void {
        self.emitByte(OpCode.RETURN.toU8());
    }

    fn emitBytes(self: *Parser, byte1: u8, byte2: u8) void {
        self.emitByte(byte1);
        self.emitByte(byte2);
    }

    fn emitByte(self: *Parser, byte: u8) void {
        // TODO currentchunk
        self.compilingChunk.write(byte, if (self.previous.line < 0) 0 else @intCast(self.previous.line));
    }

    fn emitConstant(self: *Parser, val: Value) void {
        self.emitBytes(OpCode.CONSTANT.toU8(), self.makeConstant(val));
    }

    fn makeConstant(self: *Parser, val: Value) u8 {
        const constant: usize = self.compilingChunk.addConstant(val);
        if (constant > std.math.maxInt(u8)) {
            self.errorAtCurrent("Too many constants in one chunk.");
            return 0;
        }
        return @truncate(constant);
    }

    fn expression(self: *Parser) void {
        self.parsePrecedence(.ASSIGNMENT);
    }

    fn parsePrecedence(self: *Parser, prec: Precedence) void {
        self.advance();
        if (getRule(self.previous.type).prefix) |prefixRule| {
            prefixRule(self);
            while (prec.toU8() <= getRule(self.current.type).precedence.toU8()) {
                self.advance();
                if (getRule(self.previous.type).infix) |infixRule| {
                    infixRule(self);
                } else {
                    // should never happen
                    self.errorAtCurrent("Should never happen");
                }
            }
        } else {
            // prefixRule == null
            self.errorAtCurrent("Expect expression.");
        }
    }

    fn binary(self: *Parser) void {
        const operatorType: TokenType = self.previous.type;
        const rule = getRule(operatorType);
        self.parsePrecedence(rule.precedence); // +1
        switch (operatorType) {
            .PLUS => self.emitByte(OpCode.ADD.toU8()),
            .MINUS => self.emitByte(OpCode.SUBSTRACT.toU8()),
            .STAR => self.emitByte(OpCode.MULTIPLY.toU8()),
            .SLASH => self.emitByte(OpCode.DIVIDE.toU8()),
            else => return, // unreachable
        }
    }

    fn unary(self: *Parser) void {
        const operatorType: TokenType = self.previous.type;
        // compile the operand
        self.parsePrecedence(.UNARY);
        // compile the operator instruction
        switch (operatorType) {
            .MINUS => self.emitByte(OpCode.NEGATE.toU8()),
            else => return, // unreachable
        }
    }

    fn grouping(self: *Parser) void {
        self.expression();
        self.consume(.RIGHT_PAREN, "Expect ')' after expression.");
    }

    fn number(self: *Parser) void {
        const val: f64 = std.fmt.parseFloat(f64, self.previous.slice) catch 0.0;
        self.emitConstant(val);
    }

    fn consume(self: *Parser, ty: TokenType, msg: []const u8) void {
        if (self.current.type == ty) {
            self.advance();
            return;
        }
        self.errorAtCurrent(msg);
    }

    fn advance(self: *Parser) void {
        self.previous = self.current;
        while (true) {
            self.current = self.scanner.scanToken();
            // std.debug.print("tok: '{any}' '{s}'\n", .{ self.current.type, self.current.slice });
            if (self.current.type != .ERROR) break;
            self.errorAtCurrent(self.current.slice);
        }
    }

    /// in the original C its 'void error(const char* message)'
    fn errorAtCurrent(self: *Parser, msg: []const u8) void {
        self.errorAt(self.current, msg);
    }

    fn errorAtPrevious(self: *Parser, msg: []const u8) void {
        self.errorAt(self.previous, msg);
    }

    fn errorAt(self: *Parser, token: Token, msg: []const u8) void {
        if (self.panicMode) return;
        self.panicMode = true;
        std.debug.print("[line {d}] Error", .{token.line});
        switch (token.type) {
            .EOF => std.debug.print(" at end", .{}),
            .ERROR => {},
            else => std.debug.print(" at '{s}'", .{token.slice}),
        }
        std.debug.print(": {s}\n", .{msg});
        self.hadError = true;
    }
};

const Precedence = enum {
    NONE,
    ASSIGNMENT, // =
    OR, // or
    AND, // and
    EQUALITY, // == !=
    COMPARISON, // < > <= >=
    TERM, // + -
    FACTOR, // * /
    UNARY, // ! -
    CALL, // . ()
    PRIMARY,
    pub fn toU8(self: Precedence) u8 {
        return @intFromEnum(self);
    }
};

const ParseFn = ?*const fn (self: *Parser) void;

const ParseRule = struct {
    prefix: ParseFn,
    infix: ParseFn,
    precedence: Precedence,
};

fn getRule(ty: TokenType) ParseRule {
    return switch (ty) {
        .LEFT_PAREN => ParseRule{ .prefix = Parser.grouping, .infix = null, .precedence = .NONE },
        .MINUS => ParseRule{ .prefix = Parser.unary, .infix = Parser.binary, .precedence = .TERM },
        .PLUS => ParseRule{ .prefix = null, .infix = Parser.binary, .precedence = .TERM },
        .SLASH => ParseRule{ .prefix = null, .infix = Parser.binary, .precedence = .FACTOR },
        .STAR => ParseRule{ .prefix = null, .infix = Parser.binary, .precedence = .FACTOR },
        .NUMBER => ParseRule{ .prefix = Parser.number, .infix = null, .precedence = .NONE },
        else => ParseRule{ .prefix = null, .infix = null, .precedence = .NONE },
    };
}
