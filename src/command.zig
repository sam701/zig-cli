const std = @import("std");

pub const Command = struct {
    name: []const u8,
    /// Detailed command description
    description: ?[]const u8 = null,
    /// One liner for subcommands
    help: []const u8,
    options: ?[]const *Option = null,
    subcommands: ?[]const *const Command = null,
    action: ?Action = null,
};

pub const Action = fn (args: []const []const u8) anyerror!void;

pub const OptionValue = union(enum) {
    bool: bool,
    string: ?[]u8,
    int: ?i64,
    float: ?f64,
};

pub const Option = struct {
    long_name: []const u8,
    short_alias: ?u8 = null,
    help: []const u8,
    required: bool = false,
    value: OptionValue,
    value_name: []const u8 = "VALUE",
    // TODO: support value lists
};
