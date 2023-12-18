const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const command = @import("command.zig");
const value_ref = @import("value_ref.zig");

const Self = @This();

show_help: bool,
color_usage: command.ColorUsage,
option_show_help: *command.Option,
option_color_usage: *command.Option,
options: []*const command.Option,

arena: std.heap.ArenaAllocator,

pub fn init(app_color_usage: command.ColorUsage, palloc: Allocator) !*Self {
    var arena = std.heap.ArenaAllocator.init(palloc);

    var self_ptr = try arena.allocator().create(Self);
    self_ptr.arena = arena;
    var alloc = self_ptr.arena.allocator();

    self_ptr.show_help = false;
    self_ptr.color_usage = app_color_usage;

    self_ptr.option_show_help = try alloc.create(command.Option);
    self_ptr.option_show_help.* = command.Option{
        .long_name = "help",
        .short_alias = 'h',
        .help = "Show this help output.",
        .value_ref = value_ref.allocRef(&self_ptr.show_help, alloc),
    };
    self_ptr.option_color_usage = try alloc.create(command.Option);
    self_ptr.option_color_usage.* = command.Option{
        .long_name = "color",
        .help = "When to use colors (*auto*, never, always).",
        .value_ref = value_ref.allocRef(&self_ptr.color_usage, alloc),
    };

    self_ptr.options = try alloc.alloc(*const command.Option, 2);
    self_ptr.options[0] = self_ptr.option_show_help;
    self_ptr.options[1] = self_ptr.option_color_usage;
    return self_ptr;
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}
