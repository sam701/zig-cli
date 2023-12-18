const std = @import("std");
const Allocator = std.mem.Allocator;

const command = @import("command.zig");
const help = @import("./help.zig");
const argp = @import("./arg.zig");
const Printer = @import("./Printer.zig");
const vref = @import("./value_ref.zig");
const mkRef = vref.mkRef;

pub const ParseResult = command.ExecFn;

pub fn run(app: *const command.App, alloc: Allocator) anyerror!void {
    var iter = try std.process.argsWithAllocator(alloc);
    defer iter.deinit();

    var cr = try Parser(std.process.ArgIterator).init(app, iter, alloc);
    defer cr.deinit();

    const action = try cr.parse();
    return action();
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
        position_argument_ix: usize = 0,

        pub fn init(app: *const command.App, it: Iterator, alloc: Allocator) !Self {
            return Self{
                .alloc = alloc,
                .arg_iterator = it,
                .app = app,
                .command_path = try std.ArrayList(*const command.Command).initCapacity(alloc, 16),
            };
        }

        pub fn deinit(self: *Self) void {
            self.command_path.deinit();
        }

        inline fn current_command(self: *const Self) *const command.Command {
            return self.command_path.items[self.command_path.items.len - 1];
        }

        pub fn parse(self: *Self) anyerror!ParseResult {
            try self.command_path.append(&self.app.command);

            _ = self.next_arg();
            var args_only = false;
            while (self.next_arg()) |arg| {
                if (args_only) {
                    try self.handlePositionalArgument(arg);
                } else if (argp.interpret(arg)) |interpretation| {
                    args_only = try self.process_interpretation(&interpretation);
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

                        if (opt.required and opt.value_ref.element_count == 0) {
                            self.fail("missing required option '{s}'", .{opt.long_name});
                        }
                    }
                }
                switch (cmd.target) {
                    .action => |act| {
                        if (act.positional_args) |pargs| {
                            var optional = false;
                            for (pargs.args) |parg| {
                                try parg.value_ref.finalize(self.alloc);

                                if (pargs.first_optional_arg) |first_opt| {
                                    if (parg == first_opt) {
                                        optional = true;
                                    }
                                }
                                if (!optional and parg.value_ref.element_count == 0) {
                                    self.fail("missing required positional argument '{s}'", .{parg.name});
                                }
                            }
                        }
                    },
                    .subcommands => {},
                }
            }

            switch (self.current_command().target) {
                .action => |act| {
                    return act.exec;
                },
                .subcommands => {
                    self.fail("command '{s}': no subcommand provided", .{self.current_command().name});
                    unreachable;
                },
            }
        }

        fn handlePositionalArgument(self: *Self, arg: []const u8) !void {
            const cmd = self.current_command();
            switch (cmd.target) {
                .subcommands => {
                    self.fail("command '{s}' cannot have positional arguments", .{cmd.name});
                },
                .action => |act| {
                    if (act.positional_args) |posArgs| {
                        if (self.position_argument_ix >= posArgs.args.len) {
                            self.fail("unexpected positional argument '{s}'", .{arg});
                        }

                        var posArg = posArgs.args[self.position_argument_ix];
                        var posArgRef = &posArg.value_ref;
                        posArgRef.put(arg, self.alloc) catch |err| {
                            self.fail("positional argument ({s}): cannot parse '{s}' as {s}: {s}", .{ posArg.name, arg, posArgRef.value_data.type_name, @errorName(err) });
                            unreachable;
                        };
                        if (posArgRef.value_type == vref.ValueType.single) {
                            self.position_argument_ix += 1;
                        }
                    }
                },
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
                    const cmd = self.current_command();
                    switch (cmd.target) {
                        .subcommands => |cmds| {
                            for (cmds) |sc| {
                                if (std.mem.eql(u8, sc.name, some_name)) {
                                    try self.command_path.append(sc);
                                    return false;
                                }
                            }
                            self.fail("no such subcommand '{s}'", .{some_name});
                        },
                        .action => {
                            try self.handlePositionalArgument(some_name);
                        },
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
                .long => self.find_option_by_name(option_interpretation.name),
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

        fn find_option_by_name(self: *const Self, option_name: []const u8) *command.Option {
            if (std.mem.eql(u8, "help", option_name)) {
                return &help_option;
            }
            for (0..self.command_path.items.len) |ix| {
                const cmd = self.command_path.items[self.command_path.items.len - ix - 1];
                if (cmd.options) |option_list| {
                    for (option_list) |option| {
                        if (std.mem.eql(u8, option.long_name, option_name)) {
                            return option;
                        }
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
    };
}
