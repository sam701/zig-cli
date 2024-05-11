const command = @import("command.zig");

inner: *const command.PositionalArgs,

const Self = @This();

pub fn len(self: *const Self) usize {
    var cnt: usize = 0;
    if (self.inner.required) |x| {
        cnt += x.len;
    }
    if (self.inner.optional) |x| {
        cnt += x.len;
    }
    return cnt;
}

pub fn at(self: *const Self, ix: usize) *const command.PositionalArg {
    var ix2 = ix;
    if (self.inner.required) |x| {
        if (ix < x.len) {
            return &x[ix];
        } else {
            ix2 -= x.len;
        }
    }
    if (self.inner.optional) |x| {
        return &x[ix2];
    }

    unreachable;
}

pub fn iterator(self: *const Self) Iterator {
    return Iterator.init(self);
}

const Iterator = struct {
    helper: *const Self,
    len: usize,
    index: usize,

    fn init(helper: *const Self) Iterator {
        return .{
            .helper = helper,
            .len = helper.len(),
            .index = 0,
        };
    }

    pub fn next(self: *Iterator) ?*const command.PositionalArg {
        if (self.index >= self.len) return null;

        const x = self.helper.at(self.index);
        self.index += 1;
        return x;
    }
};
