const std = @import("std");

const isDigit = std.ascii.isDigit;
pub const TokenType = enum {
    // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,
    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,
    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,
    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    ERROR,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    // the source string is kept around in memory, so it should not be freed
    // before that
    slice: []const u8,
    line: i32,
    fn make(scanner: Scanner, ty: TokenType) Token {
        return Token{
            .type = ty,
            .slice = scanner.start[0..(scanner.current - scanner.start)],
            .line = scanner.line,
        };
    }
    fn err(scanner: Scanner, comptime msg: []const u8) Token {
        return Token{
            .type = .ERROR,
            .slice = msg,
            .line = scanner.line,
        };
    }
};

pub const Scanner = struct {
    // Scanner doesn't own 'source', so it does not free it
    // All else is not allocated, so doesn't need to be freed
    source: *const []const u8,
    start: [*]const u8,
    current: [*]const u8,
    line: i32,
    pub fn new(source: *const []const u8) Scanner {
        return Scanner{
            .source = source,
            .start = source.ptr,
            .current = source.ptr,
            .line = 1,
        };
    }
    pub fn scanToken(self: *Scanner) Token {
        // std.Thread.sleep(1000000000);
        // std.debug.print("scanToken\n", .{});
        self.skipWhitespace();

        self.start = self.current;

        // self.dumpScanner();
        if (self.isAtEnd()) return Token.make(self.*, .EOF);

        const c = self.advance();
        // std.debug.print("char scanner '{c}'\n", .{c});
        if (isAlpha(c)) return self.identifier();
        return switch (c) {
            '0'...'9' => self.number(),
            '(' => Token.make(self.*, .LEFT_PAREN),
            ')' => Token.make(self.*, .RIGHT_PAREN),
            '{' => Token.make(self.*, .LEFT_BRACE),
            '}' => Token.make(self.*, .RIGHT_BRACE),
            ';' => Token.make(self.*, .SEMICOLON),
            ',' => Token.make(self.*, .COMMA),
            '.' => Token.make(self.*, .DOT),
            '-' => Token.make(self.*, .MINUS),
            '+' => Token.make(self.*, .PLUS),
            '/' => Token.make(self.*, .SLASH),
            '*' => Token.make(self.*, .STAR),
            '!' => Token.make(self.*, if (match(self, '=')) .BANG_EQUAL else .BANG),
            '=' => Token.make(self.*, if (match(self, '=')) .EQUAL_EQUAL else .EQUAL),
            '<' => Token.make(self.*, if (match(self, '=')) .LESS_EQUAL else .LESS),
            '>' => Token.make(self.*, if (match(self, '=')) .GREATER_EQUAL else .GREATER),
            '"' => self.string(),
            else => return Token.err(self.*, "Unexpected character."),
        };
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd() or (self.current[0] != expected)) return false;
        self.current += 1;
        return true;
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return (self.current - 1)[0];
    }

    fn isAtEnd(self: *Scanner) bool {
        const sourceStart: [*]const u8 = self.source.*.ptr;
        const offset: usize = @intFromPtr(self.current) - @intFromPtr(sourceStart);
        const comp = offset >= self.source.len;
        // std.debug.print("isAtEnd(): {any}, offset: {d}, source.len: {d}\n", .{ comp, offset, self.source.len });

        return comp;
    }

    fn peek(self: *Scanner) u8 {
        return self.current[0];
    }

    fn peekNext(self: *Scanner) u8 {
        return if (self.isAtEnd()) 0 else self.current[1];
    }

    fn skipWhitespace(self: *Scanner) void {
        while (true) {
            switch (self.peek()) {
                ' ', '\r' | '\t' => {
                    _ = self.advance();
                },
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        // comments go to the end of the line
                        while (self.peek() != '\n' and !self.isAtEnd()) {
                            _ = self.advance();
                        }
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    fn string(self: *Scanner) Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }
        if (self.isAtEnd()) return Token.err(self.*, "Unterminated string.");

        // close qoute
        _ = self.advance();
        // TODO: original C code doesn't seem to account for this?
        var tok = Token.make(self.*, .STRING);
        tok.slice = tok.slice[1 .. tok.slice.len - 1];
        return tok;
    }

    fn number(self: *Scanner) Token {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }

        // look for fractional part
        if (self.peek() == '.' and std.ascii.isDigit(self.peekNext())) {
            // consume '.'
            _ = self.advance();

            while (std.ascii.isDigit(self.peek())) {
                _ = self.advance();
            }
        }

        return Token.make(self.*, .NUMBER);
    }

    fn identifier(self: *Scanner) Token {
        while (isAlpha(self.peek()) or isDigit(self.peek())) _ = self.advance();
        return Token.make(self.*, self.identifierType());
    }

    fn identifierType(self: *Scanner) TokenType {
        return switch (self.start[0]) {
            'a' => self.checkKeyword(1, "nd", .AND),
            'c' => self.checkKeyword(1, "lass", .CLASS),
            'e' => self.checkKeyword(1, "lse", .ELSE),
            'f' => blk: {
                if ((self.current - self.start) > 1) {
                    break :blk switch (self.start[1]) {
                        'a' => self.checkKeyword(2, "lse", .FALSE),
                        'o' => self.checkKeyword(2, "r", .FOR),
                        'u' => self.checkKeyword(2, "n", .FUN),
                        else => .IDENTIFIER,
                    };
                }
                break :blk .IDENTIFIER;
            },
            'i' => self.checkKeyword(1, "f", .IF),
            'n' => self.checkKeyword(1, "il", .NIL),
            'o' => self.checkKeyword(1, "r", .OR),
            'p' => self.checkKeyword(1, "rint", .PRINT),
            'r' => self.checkKeyword(1, "eturn", .RETURN),
            's' => self.checkKeyword(1, "uper", .SUPER),
            't' => blk: {
                if (self.current - self.start > 1) {
                    break :blk switch (self.start[1]) {
                        'h' => self.checkKeyword(2, "is", .THIS),
                        'r' => self.checkKeyword(2, "ue", .TRUE),
                        else => .IDENTIFIER,
                    };
                }
                break :blk .IDENTIFIER;
            },
            'v' => self.checkKeyword(1, "ar", .VAR),
            'w' => self.checkKeyword(1, "hile", .WHILE),
            else => .IDENTIFIER,
        };
    }

    fn checkKeyword(self: *Scanner, start: u4, rest: []const u8, ty: TokenType) TokenType {
        if (std.mem.eql(u8, self.start[start .. start + rest.len], // get slice of the current token
            rest))
        {
            return ty;
        }
        return .IDENTIFIER;
    }

    fn dumpScanner(self: Scanner) void {
        std.debug.print("-------------\n", .{});
        std.debug.print("source: {s}\n", .{self.source.*});
        std.debug.print("start: {c}\n", .{self.start[0]});
        std.debug.print("current: {c}\n", .{self.current[0]});
        std.debug.print("line: {d}\n", .{self.line});
    }
};

fn isAlpha(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '_' => true,
        else => false,
    };
}
