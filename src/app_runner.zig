const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const value_ref = @import("value_ref.zig");
const ValueRef = value_ref.ValueRef;
const App = @import("command.zig").App;
const Parser = @import("parser.zig").Parser;

pub const AppRunner = struct {
    arena: ArenaAllocator,
    alloc: Allocator,

    const Self = @This();
    pub fn init(alloc: Allocator) !*Self {
        var arena = ArenaAllocator.init(alloc);
        var sptr = try arena.allocator().create(Self);

        sptr.arena = arena;
        sptr.alloc = sptr.arena.allocator();
        return sptr;
    }

    pub fn mkRef(self: *Self, dest: anytype) *ValueRef {
        return value_ref.allocRef(dest, self.alloc);
    }

    pub fn run(self: *Self, app: *const App) anyerror!void {
        const iter = try std.process.argsWithAllocator(self.alloc);
        var cr = try Parser(std.process.ArgIterator).init(app, iter, self.alloc);

        const action = try cr.parse();
        self.arena.deinit();
        return action();
    }
};
