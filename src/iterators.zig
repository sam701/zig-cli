const std = @import("std");
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

pub const StringSliceIterator = struct {
    items: []const []const u8,
    index: usize = 0,

    pub fn next(self: *StringSliceIterator) ?[]const u8 {
        defer self.index += 1;

        if (self.index < self.items.len) {
            return self.items[self.index];
        } else {
            return null;
        }
    }
};

pub const SystemArgIterator = struct {
    iter: *ArgIterator,
    alloc: Allocator,

    pub fn next(self: *SystemArgIterator) ?[]const u8 {
        if (self.iter.next(self.alloc)) |arg| {
            return arg catch unreachable;
        } else {
            return null;
        }
    }
};
