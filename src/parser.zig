const std = @import("std");
const Allocator = std.mem.Allocator;

const command = @import("command.zig");
const help = @import("./help.zig");
const argp = @import("./arg.zig");
const Printer = @import("./Printer.zig");
const mkRef = @import("./value_ref.zig").mkRef;

pub const ParseResult = struct {
    action: command.Action,
    args: []const []const u8,
};

pub fn run(app: *const command.App, alloc: Allocator) anyerror!void {
    var iter = try std.process.argsWithAllocator(alloc);
    defer iter.deinit();

    var cr = try Parser(std.process.ArgIterator).init(app, iter, alloc);
    defer cr.deinit();

    var result = try cr.parse();
    return result.action(result.args);
}

var help_option_set: bool = false;

var help_option = command.Option{
    .long_name = "help",
    .help = "Show this help output.",
    .short_alias = 'h',
    .value_ref = mkRef(&help_option_set),
};

pub fn Parser(comptime Iterator: type) type {
    return struct {
        const Self = @This();

        alloc: Allocator,
        arg_iterator: Iterator,
        app: *const command.App,
        command_path: std.ArrayList(*const command.Command),
        captured_arguments: std.ArrayList([]const u8),

        pub fn init(app: *const command.App, it: Iterator, alloc: Allocator) !Self {
            return Self{
                .alloc = alloc,
                .arg_iterator = it,
                .app = app,
                .command_path = try std.ArrayList(*const command.Command).initCapacity(alloc, 16),
                .captured_arguments = try std.ArrayList([]const u8).initCapacity(alloc, 16),
            };
        }

        pub fn deinit(self: *Self) void {
            self.captured_arguments.deinit();
            self.command_path.deinit();
        }

        inline fn current_command(self: *const Self) *const command.Command {
            return self.command_path.items[self.command_path.items.len - 1];
        }

        pub fn parse(self: *Self) anyerror!ParseResult {
            const app_command = command.Command{
                .name = self.app.name,
                .description = self.app.description,
                .help = "",
                .action = self.app.action,
                .subcommands = self.app.subcommands,
                .options = self.app.options,
            };
            try self.command_path.append(&app_command);

            self.validate_command(&app_command);
            _ = self.next_arg();
            var args_only = false;
            while (self.next_arg()) |arg| {
                if (args_only) {
                    try self.captured_arguments.append(arg);
                } else if (argp.interpret(arg)) |int| {
                    args_only = try self.process_interpretation(&int);
                } else |err| {
                    switch (err) {
                        error.MissingOptionArgument => self.fail("missing argument: '{s}'", .{arg}),
                    }
                }
            }
            return self.finalize();
        }

        fn finalize(self: *Self) !ParseResult {
            for (self.command_path.items) |cmd| {
                if (cmd.options) |options| {
                    for (options) |opt| {
                        try self.set_option_value_from_envvar(opt);
                        try opt.value_ref.finalize(self.alloc);
                    }
                }
            }

            self.ensure_all_required_set(self.current_command());
            var args = try self.captured_arguments.toOwnedSlice();

            if (self.current_command().action) |action| {
                return ParseResult{ .action = action, .args = args };
            } else {
                self.fail("command '{s}': no subcommand provided", .{self.current_command().name});
                unreachable;
            }
        }

        fn set_option_value_from_envvar(self: *const Self, opt: *command.Option) !void {
            if (opt.value_ref.element_count > 0) return;

            if (opt.envvar) |envvar_name| {
                if (std.os.getenv(envvar_name)) |value| {
                    opt.value_ref.put(value, self.alloc) catch |err| {
                        self.fail("envvar({s}): cannot parse {s} value '{s}': {s}", .{ envvar_name, opt.value_ref.value_data.type_name, value, @errorName(err) });
                        unreachable;
                    };
                }
            } else if (self.app.option_envvar_prefix) |prefix| {
                var envvar_name = try self.alloc.alloc(u8, opt.long_name.len + prefix.len + 1);
                defer self.alloc.free(envvar_name);
                @memcpy(envvar_name[0..prefix.len], prefix);
                envvar_name[prefix.len] = '_';
                for (envvar_name[prefix.len + 1 ..], opt.long_name) |*dest, name_char| {
                    if (name_char == '-') {
                        dest.* = '_';
                    } else {
                        dest.* = std.ascii.toUpper(name_char);
                    }
                }

                if (std.os.getenv(envvar_name)) |value| {
                    opt.value_ref.put(value, self.alloc) catch |err| {
                        self.fail("envvar({s}): cannot parse {s} value '{s}': {s}", .{ envvar_name, opt.value_ref.value_data.type_name, value, @errorName(err) });
                        unreachable;
                    };
                }
            }
        }

        fn process_interpretation(self: *Self, int: *const argp.ArgumentInterpretation) !bool {
            var args_only = false;
            try switch (int.*) {
                .option => |opt| self.process_option(&opt),
                .double_dash => {
                    args_only = true;
                },
                .other => |some_name| {
                    if (find_subcommand(self.current_command(), some_name)) |cmd| {
                        self.ensure_all_required_set(self.current_command());
                        self.validate_command(cmd);
                        try self.command_path.append(cmd);
                    } else {
                        try self.captured_arguments.append(some_name);
                    }
                },
            };
            return args_only;
        }

        fn next_arg(self: *Self) ?[]const u8 {
            return self.arg_iterator.next();
        }

        fn process_option(self: *Self, option_interpretation: *const argp.OptionInterpretation) !void {
            var opt: *command.Option = switch (option_interpretation.option_type) {
                .long => self.find_option_by_name(self.current_command(), option_interpretation.name),
                .short => a: {
                    self.set_concatenated_boolean_options(self.current_command(), option_interpretation.name[0 .. option_interpretation.name.len - 1]);
                    break :a self.find_option_by_alias(self.current_command(), option_interpretation.name[option_interpretation.name.len - 1]);
                },
            };

            if (opt == &help_option) {
                try help.print_command_help(self.app, try self.command_path.toOwnedSlice());
                std.os.exit(0);
            }

            if (opt.value_ref.value_data.is_bool) {
                try opt.value_ref.put("true", self.alloc);
                // TODO: bool argument can be explicitly passed as a value
            } else {
                const arg = option_interpretation.value orelse self.next_arg() orelse {
                    self.fail("missing argument for {s}", .{opt.long_name});
                    unreachable;
                };
                opt.value_ref.put(arg, self.alloc) catch |err| {
                    self.fail("option({s}): cannot parse {s} value: {s}", .{ opt.long_name, opt.value_ref.value_data.type_name, @errorName(err) });
                    unreachable;
                };
            }
        }

        fn fail(self: *const Self, comptime fmt: []const u8, args: anytype) void {
            var p = Printer.init(std.io.getStdErr(), self.app.help_config.color_usage);

            p.printInColor(self.app.help_config.color_error, "ERROR");
            p.format(": ", .{});
            p.format(fmt, args);
            p.write(&.{'\n'});
            std.os.exit(1);
        }

        fn find_option_by_name(self: *const Self, cmd: *const command.Command, option_name: []const u8) *command.Option {
            if (std.mem.eql(u8, "help", option_name)) {
                return &help_option;
            }
            if (cmd.options) |option_list| {
                for (option_list) |option| {
                    if (std.mem.eql(u8, option.long_name, option_name)) {
                        return option;
                    }
                }
            }
            self.fail("no such option '--{s}'", .{option_name});
            unreachable;
        }

        fn find_option_by_alias(self: *const Self, cmd: *const command.Command, option_alias: u8) *command.Option {
            if (option_alias == 'h') {
                return &help_option;
            }
            if (cmd.options) |option_list| {
                for (option_list) |option| {
                    if (option.short_alias) |alias| {
                        if (alias == option_alias) {
                            return option;
                        }
                    }
                }
            }
            self.fail("no such option alias '-{c}'", .{option_alias});
            unreachable;
        }

        fn validate_command(self: *const Self, cmd: *const command.Command) void {
            if (cmd.subcommands == null) {
                if (cmd.action == null) {
                    self.fail("command '{s}' has neither subcommands no an aciton assigned", .{cmd.name});
                }
            } else {
                if (cmd.action != null) {
                    self.fail("command '{s}' has subcommands and an action assigned. Commands with subcommands are not allowed to have action.", .{cmd.name});
                }
            }
        }

        /// Set boolean options provided like `-acde`
        fn set_concatenated_boolean_options(self: *const Self, cmd: *const command.Command, options: []const u8) void {
            for (options) |alias| {
                var opt = self.find_option_by_alias(cmd, alias);
                if (opt.value_ref.value_data.is_bool) {
                    opt.value_ref.put("true", self.alloc) catch unreachable;
                } else {
                    self.fail("'-{c}' is not a boolean option", .{alias});
                }
            }
        }

        fn ensure_all_required_set(self: *const Self, cmd: *const command.Command) void {
            if (cmd.options) |list| {
                for (list) |option| {
                    if (option.required and option.value_ref.element_count == 0) {
                        self.fail("missing required option '{s}'", .{option.long_name});
                    }
                }
            }
        }
    };
}

fn find_subcommand(cmd: *const command.Command, subcommand_name: []const u8) ?*const command.Command {
    if (cmd.subcommands) |sc_list| {
        for (sc_list) |sc| {
            if (std.mem.eql(u8, sc.name, subcommand_name)) {
                return sc;
            }
        }
    }
    return null;
}
