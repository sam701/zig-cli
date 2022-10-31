const std = @import("std");
const Allocator = std.mem.Allocator;

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
