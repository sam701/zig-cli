const std = @import("std");
const ValueRef = @import("./value_ref.zig").ValueRef;

/// Main structure for the application.
pub const App = struct {
    /// Main command configuration.
    command: Command,
    /// Optional version information.
    version: ?[]const u8 = null,
    /// Optional author information.
    author: ?[]const u8 = null,
    /// If set, all options can be set by providing an environment variable.
    /// For example, an option with a long name `hello_world` can be set by setting `<prefix in upper case>_HELLO_WORLD` environment variable.
    option_envvar_prefix: ?[]const u8 = null,
    /// Help display configuration.
    help_config: HelpConfig = HelpConfig{},
};

/// Enumeration for color usage in help display.
pub const ColorUsage = enum {
    always,
    never,
    auto,
};

/// Configuration for help display.
pub const HelpConfig = struct {
    /// Color usage setting.
    color_usage: ColorUsage = .auto,
    /// Color for the application name in help.
    color_app_name: []const u8 = "33;1",
    /// Color for section headers in help.
    color_section: []const u8 = "33;1",
    /// Color for option names in help.
    color_option: []const u8 = "32",
    /// Color for error messages in help.
    color_error: []const u8 = "31;1",
};

/// Structure representing a command.
pub const Command = struct {
    /// Name of the command.
    name: []const u8,
    /// Description of the command.
    description: ?Description = null,
    /// List of options for the command.
    options: ?[]const *Option = null,
    /// Target of the command (subcommands or action).
    target: CommandTarget,
};

/// Structure representing a description.
pub const Description = struct {
    /// One-line description.
    one_line: []const u8,
    /// Detailed description (optional).
    detailed: ?[]const u8 = null,
};

/// Union for different command targets.
pub const CommandTarget = union(enum) {
    /// Subcommands of the command.
    subcommands: []const *const Command,
    /// Action to execute for the command.
    action: CommandAction,
};

/// Structure representing a command action.
pub const CommandAction = struct {
    /// Positional arguments for the action.
    positional_args: ?PositionalArgs = null,
    /// Function to execute for the action.
    exec: ExecFn,
};

/// Function pointer type for command execution.
pub const ExecFn = *const fn () anyerror!void;

/// Structure representing an option.
pub const Option = struct {
    /// Long name of the option.
    long_name: []const u8,
    /// Short alias for the option.
    short_alias: ?u8 = null,
    /// Help description for the option.
    help: []const u8,
    /// Whether the option is required or not.
    required: bool = false,
    /// Reference to the value of the option.
    value_ref: ValueRef,
    /// Name of the value for the option.
    value_name: []const u8 = "VALUE",
    /// Environment variable name for the option.
    envvar: ?[]const u8 = null,
};

/// Structure representing positional arguments for an action.
pub const PositionalArgs = struct {
    /// List of positional arguments.
    args: []const *PositionalArg,
    /// If not set, all positional arguments are considered as required.
    first_optional_arg: ?*const PositionalArg = null,
};

/// Structure representing a positional argument.
pub const PositionalArg = struct {
    /// Name of the positional argument.
    name: []const u8,
    /// Help description for the positional argument.
    help: []const u8,
    /// Reference to the value of the positional argument.
    value_ref: ValueRef,
};
