const std = @import("std");

const memory = @import("memory.zig");
const vm = @import("vm.zig");
const VM = vm.VM;

pub const ObjType = enum(u8) {
    string,
    fn toStructType(self: ObjType) type {
        return switch (self) {
            .string => ObjString,
        };
    }
};

pub const Obj = struct {
    type: ObjType,
    next: ?*Obj,
    pub fn asObjString(self: *Obj) *ObjString {
        return @alignCast(@fieldParentPtr("obj", self));
    }
    fn allocateObj(vmi: *VM, comptime ty: ObjType) *ty.toStructType() {
        const objPtr = vmi.allocator.create(ty.toStructType()) catch |err| memory.panicMemAllocating("object", err);
        objPtr.obj.type = ty;
        objPtr.obj.next = vmi.objects;
        vmi.objects = objPtr.asObj();
        return objPtr;
    }

    pub fn free(self: *Obj, allocator: std.mem.Allocator) void {
        switch (self.type) {
            .string => {
                const objString = self.asObjString();
                allocator.free(objString.str);
                allocator.destroy(objString);
            },
        }
    }

    pub fn print(self: *Obj) void {
        switch (self.type) {
            .string => std.debug.print("\"{s}\"", .{self.asObjString().str}),
        }
    }
};
pub const ObjString = struct {
    obj: Obj,
    str: []u8,
    pub fn asObj(self: *ObjString) *Obj {
        return &self.obj;
    }

    /// Returns heap-allocated `ObjString`, by copying `str` slice.
    pub fn copyFromString(vmi: *VM, str: []const u8) *ObjString {
        const newStr = vmi.allocator.dupe(u8, str) catch |err| memory.panicMemDuplicating("string", err);
        return allocateObjString(vmi, newStr);
    }
    /// The `str` must be heap-allocated, and is now owned by the new `*ObjString` allocated.
    pub fn allocateObjString(vmi: *VM, str: []u8) *ObjString {
        const objStrPtr = Obj.allocateObj(vmi, ObjType.string);
        objStrPtr.str = str;
        return objStrPtr;
    }
};
