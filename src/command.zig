const std = @import("std");
pub const ValueRef = @import("./value_ref.zig").ValueRef;

pub const App = struct {
    command: Command,
    version: ?[]const u8 = null,
    author: ?[]const u8 = null,

    /// If set all options can be set by providing an environment variable.
    /// For example an option with a long name `hello_world` can be set by setting `<prefix in upper case>_HELLO_WORLD` environment variable.
    option_envvar_prefix: ?[]const u8 = null,

    help_config: HelpConfig = HelpConfig{},
};

pub const ColorUsage = enum {
    always,
    never,
    auto,
};

pub const HelpConfig = struct {
    color_usage: ColorUsage = .auto,
    color_app_name: []const u8 = "33;1",
    color_section: []const u8 = "33;1",
    color_option: []const u8 = "32",
    color_error: []const u8 = "31;1",
};

pub const Command = struct {
    name: []const u8,
    description: ?Description = null,
    options: ?[]const Option = null,
    target: CommandTarget,
};

pub const Description = struct {
    one_line: []const u8,
    detailed: ?[]const u8 = null,
};

pub const CommandTarget = union(enum) {
    subcommands: []const Command,
    action: CommandAction,
};

pub const CommandAction = struct {
    positional_args: ?PositionalArgs = null,
    exec: ExecFn,
};

pub const ExecFn = *const fn () anyerror!void;

pub const Option = struct {
    long_name: []const u8,
    short_alias: ?u8 = null,
    help: []const u8,
    required: bool = false,
    value_ref: *ValueRef,
    value_name: []const u8 = "VALUE",
    envvar: ?[]const u8 = null,
};

pub const PositionalArgs = struct {
    required: ?[]const PositionalArg = null,
    optional: ?[]const PositionalArg = null,
};

pub const PositionalArg = struct {
    name: []const u8,
    help: []const u8,
    value_ref: *ValueRef,
};
