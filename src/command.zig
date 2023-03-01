const std = @import("std");

pub const App = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    version: ?[]const u8 = null,
    options: ?[]const *Option = null,
    subcommands: ?[]const *const Command = null,
    action: ?Action = null,

    help_config: HelpConfig = HelpConfig{
        .color = .Auto,
    },
};

pub const ColorUsage = enum {
    Always,
    Never,
    Auto,
};

pub const HelpConfig = struct {
    color: ColorUsage,
};

pub const Command = struct {
    name: []const u8,
    /// Detailed multiline command description
    description: ?[]const u8 = null,
    /// One liner for subcommands
    help: []const u8,
    options: ?[]const *Option = null,
    subcommands: ?[]const *const Command = null,
    action: ?Action = null,
};

pub const Action = *const fn (args: []const []const u8) anyerror!void;

pub const OptionValue = union(enum) {
    bool: bool,
    string: ?[]const u8,
    int: ?i64,
    float: ?f64,
    string_list: ?[]const []const u8,
};

pub const Option = struct {
    long_name: []const u8,
    short_alias: ?u8 = null,
    help: []const u8,
    required: bool = false,
    value: OptionValue,
    value_name: []const u8 = "VALUE",
};
