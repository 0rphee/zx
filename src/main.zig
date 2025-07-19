//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

pub fn main() !i32 {
    return 0;
}

test "simple test" {
    try std.testing.expect(true);
}
