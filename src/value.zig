const std = @import("std");
pub const Value = f64;
pub const ValueArray = struct { values: std.ArrayList(Value) };
