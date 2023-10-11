const std = @import("std");
const command = @import("./command.zig");
const vp = @import("./value_parser.zig");

pub const ValueRef = struct {
    impl_ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    const VTable = struct {
        put: *const fn (impl_ptr: *anyopaque, value: []const u8) anyerror!void,

        /// finalize and destroy
        finalize: *const fn (impl_ptr: *anyopaque) anyerror!void,
    };

    pub fn put(self: *Self, value: []const u8) anyerror!void {
        return self.vtable.put(self.impl_ptr, value);
    }
    pub fn finalize(self: *Self) anyerror!void {
        return self.vtable.finalize(self.impl_ptr);
    }
};

// TODO: can ValueRef be an enum????

const AllocError = std.mem.Allocator.Error;
pub const Error = AllocError; // | error{NotImplemented};

pub const Context = struct {
    alloc: std.mem.Allocator,

    pub fn init(a: std.mem.Allocator) Context {
        return .{
            .alloc = a,
        };
    }

    fn singleValueRef(ctx: *Context, comptime T: type, dest: *T, parser: vp.ValueParser(T)) AllocError!ValueRef {
        const Impl = struct {
            dest: *T,
            parser: vp.ValueParser(T),
            alloc: std.mem.Allocator,

            const Self = @This();

            fn put(ptr: *anyopaque, value: []const u8) anyerror!void {
                const self: *Self = @ptrCast(@alignCast(ptr));
                try self.parser(self.dest, value);
            }
            fn finalize(ptr: *anyopaque) anyerror!void {
                const self: *Self = @ptrCast(@alignCast(ptr));

                // TODO: clarify what to do with copied strings???
                self.alloc.destroy(self);
            }
        };

        // FIXME: this must be destroyed
        const im = try ctx.alloc.create(Impl);
        im.* = .{
            .dest = dest,
            .parser = parser,
            .alloc = ctx.alloc,
        };

        return ValueRef{ .impl_ptr = im, .vtable = &.{
            .put = Impl.put,
            .finalize = Impl.finalize,
        } };
    }

    pub fn sliceRef(ctx: *Context, comptime T: type, dest: *[]const T, parser: vp.ValueParser(T)) AllocError!ValueRef {
        const List = std.ArrayList(T);
        const Impl = struct {
            dest: *[]const T,
            parser: vp.ValueParser(T),
            list: List,
            alloc2: std.mem.Allocator,

            const Self = @This();

            fn put(ptr: *anyopaque, value: []const u8) anyerror!void {
                const self: *Self = @ptrCast(@alignCast(ptr));
                var x: T = undefined;
                try self.parser(&x, value);
                try self.list.append(x);
            }
            fn finalize(ptr: *anyopaque) anyerror!void {
                const self: *Self = @ptrCast(@alignCast(ptr));
                self.dest.* = try self.list.toOwnedSlice();
                self.alloc2.destroy(self);
            }
        };

        // FIXME: this must be destroyed
        const im = try ctx.alloc.create(Impl);
        im.* = .{
            .dest = dest,
            .parser = parser,
            .list = List.init(ctx.alloc),
            .alloc2 = ctx.alloc,
        };

        return ValueRef{ .impl_ptr = im, .vtable = &.{
            .put = Impl.put,
            .finalize = Impl.finalize,
        } };
    }

    pub fn valueRef(ctx: *Context, comptime dest: anytype) Error!ValueRef {
        const ti = @typeInfo(@TypeOf(dest));
        const t = ti.Pointer.child;

        switch (@typeInfo(t)) {
            .Pointer => |pinfo| {
                switch (pinfo.size) {
                    .Slice => {
                        const p = vp.get(pinfo.child);
                        return ctx.sliceRef(pinfo.child, dest, p);
                    },
                    else => @compileError("unsupported value type"),
                }
            },
            else => {
                const p = vp.get(t);
                return ctx.singleValueRef(t, dest, p);
            },
        }
    }
};
