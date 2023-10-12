const std = @import("std");
const command = @import("./command.zig");
const vp = @import("./value_parser.zig");

pub const ValueRef = struct {
    dest: *anyopaque,
    value_data: vp.ValueData,
    value_type: ValueType,
    element_count: usize = 0,

    const Self = @This();

    pub fn put(self: *Self, value: []const u8, alloc: std.mem.Allocator) anyerror!void {
        switch (self.value_type) {
            .single => {
                self.element_count += 1;
                return self.value_data.value_parser(self.dest, value);
            },
            .multi => |*list| {
                self.element_count += 1;
                try list.ensureTotalCapacity(alloc, self.element_count * self.value_data.value_size);
                const value_ptr = list.items.ptr + ((self.element_count - 1) * self.value_data.value_size);
                try self.value_data.value_parser(value_ptr, value);
                list.items.len += self.value_data.value_size;
            },
        }
    }

    pub fn finalize(self: *Self, alloc: std.mem.Allocator) anyerror!void {
        switch (self.value_type) {
            .single => {},
            .multi => |*list| {
                var sl = try list.toOwnedSlice(alloc);
                sl.len = self.element_count;

                var dest: *[]u8 = @alignCast(@ptrCast(self.dest));
                dest.* = sl;
            },
        }
    }
};

const ValueType = union(enum) {
    single,
    multi: std.ArrayListUnmanaged(u8),
};

const AllocError = std.mem.Allocator.Error;
pub const Error = AllocError; // | error{NotImplemented};

pub fn mkRef(dest: anytype) ValueRef {
    const ti = @typeInfo(@TypeOf(dest));
    const t = ti.Pointer.child;

    switch (@typeInfo(t)) {
        .Pointer => |pinfo| {
            switch (pinfo.size) {
                .Slice => {
                    if (pinfo.child == u8) {
                        return ValueRef{
                            .dest = @ptrCast(dest),
                            .value_data = vp.getValueData(t),
                            .value_type = .single,
                        };
                    } else {
                        return ValueRef{
                            .dest = @ptrCast(dest),
                            .value_data = vp.getValueData(pinfo.child),
                            .value_type = ValueType{ .multi = std.ArrayListUnmanaged(u8){} },
                        };
                    }
                },
                else => @compileError("unsupported value type: only slices are supported"),
            }
        },
        else => {
            return ValueRef{
                .dest = dest,
                .value_data = vp.getValueData(t),
                .value_type = .single,
            };
        },
    }
}
