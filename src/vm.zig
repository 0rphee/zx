const std = @import("std");

const common = @import("common.zig");
const Chunk = common.Chunk;
const OpCode = common.OpCode;
const debug = @import("debug.zig");
const value = @import("value.zig");
const Value = value.Value;

pub const InterpretResult = enum { ok, compile_err, runtime_err };

pub const VM = struct {
    chunk: *Chunk,
    ip: [*]u8, // ptr to next instruction to execute
    pub fn new(
        // chunk: *Chunk
    )
    // VM
    void {}
    pub fn free() void {}
    pub fn interpret(chunk: *Chunk) InterpretResult {
        var vm = VM{
            .chunk = chunk,
            .ip = @as([*]u8, chunk.code.items.ptr),
        };
        return vm.run();
    }
    fn readByte(vm: *VM) OpCode {
        const old = vm.ip;
        vm.ip += 1;
        return @enumFromInt(old[0]);
    }
    fn readConstant(vm: *VM) f64 {
        return vm.chunk.constants.items[readByte(vm).toU8()];
    }
    pub fn run(self: *VM) InterpretResult {
        while (true) {
            if (comptime common.DEBUG_TRACE_EXECUTION) {
                _ = debug.disassembleInstruction(self.chunk, @intFromPtr(self.ip) - @intFromPtr(self.chunk.code.items.ptr));
            }

            switch (readByte(self)) {
                .OP_CONSTANT => {
                    const constant: Value = readConstant(self);
                    value.printValue(constant);
                    std.debug.print("\n", .{});
                },
                .OP_RETURN => return .ok,
                else => {
                    return .runtime_err;
                },
            }
        }
        return undefined;
    }
};
