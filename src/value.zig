const std = @import("std");

pub const ValueType = enum { bool, nil, number };

pub const Value = union(ValueType) {
    bool: bool,
    nil: void,
    number: f64,
    pub fn ty(value: Value) ValueType {
        return value;
    }

    pub fn print(value: Value) void {
        switch (value) {
            .bool => |v| std.debug.print("{any}", .{v}),
            .nil => std.debug.print("nil", .{}),
            .number => |v| std.debug.print("{e}", .{v}),
        }
    }

    pub fn boolVal(b: bool) Value {
        return Value{ .bool = b };
    }
    pub fn nilVal() Value {
        return Value{ .nil = {} };
    }
    pub fn numberVal(n: f64) Value {
        return Value{ .number = n };
    }
    pub fn isNil(self: Value) bool {
        return switch (self) {
            .nil => true,
            else => false,
        };
    }
    pub fn isBool(self: Value) bool {
        return switch (self) {
            .bool => true,
            else => false,
        };
    }
    pub fn isNumber(self: Value) bool {
        return switch (self) {
            .number => true,
            else => false,
        };
    }
    pub fn isFalsey(self: Value) bool {
        return switch (self) {
            .nil => true,
            .bool => |v| !v,
            else => false,
        };
    }
    pub fn equal(self: Value, other: Value) bool {
        return if (self.ty() != other.ty()) false else switch (self) {
            .bool => |v| v == other.bool,
            .nil => true,
            .number => |v| v == other.number,
            // else => false, //unreachable
        };
    }
};
