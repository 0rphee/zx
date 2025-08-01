const std = @import("std");

const object = @import("object.zig");
const ObjType = object.ObjType;
const Obj = object.Obj;
const ObjString = object.ObjString;

pub const ValueType = enum { bool, nil, number, obj };

pub const Value = union(ValueType) {
    bool: bool,
    nil: void,
    number: f64,
    obj: *Obj,
    pub fn ty(value: Value) ValueType {
        return value;
    }

    pub fn print(value: Value) void {
        switch (value) {
            .bool => |v| std.debug.print("{any}", .{v}),
            .nil => std.debug.print("nil", .{}),
            .number => |v| std.debug.print("{e}", .{v}),
            .obj => |v| v.print(),
        }
    }

    pub fn boolVal(b: bool) Value {
        return Value{ .bool = b };
    }
    pub fn nilVal() Value {
        return Value{ .nil = {} };
    }
    pub fn numberVal(v: f64) Value {
        return Value{ .number = v };
    }
    pub fn objVal(v: *Obj) Value {
        return Value{ .obj = v };
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
    pub fn isObj(self: Value) bool {
        return switch (self) {
            .obj => true,
            else => false,
        };
    }

    pub fn isObjType(self: Value, t: ObjType) bool {
        return switch (self) {
            .obj => |v| v.type == t,
            else => false,
        };
    }

    pub fn isString(self: Value) bool {
        return self.isObjType(.string);
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
            // TODO: change when more obj types are valid
            .obj => |v| std.mem.eql(u8, v.asObjString().str, other.obj.asObjString().str),
        };
    }
};
