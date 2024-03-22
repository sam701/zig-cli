const std = @import("std");
const Allocator = std.mem.Allocator;

const command = @import("command.zig");
const help = @import("./help.zig");
const argp = @import("./arg.zig");
const Printer = @import("./Printer.zig");
const vref = @import("./value_ref.zig");
const mkRef = vref.mkRef;
const value_parser = @import("value_parser.zig");
const str_true = value_parser.str_true;
const str_false = value_parser.str_false;
const GlobalOptions = @import("GlobalOptions.zig");
const PositionalArgsHelper = @import("PositionalArgsHelper.zig");

pub const ParseResult = command.ExecFn;

pub const EntityType = enum {
    option,
    positional_argument,
};
pub const ErrorData = union {
    provided_string: []const u8,
    entity_name: []const u8,
    option_alias: u8,
    invalid_value: struct {
        entity_type: EntityType,
        entity_name: []const u8,
        provided_string: []const u8,
        value_type: []const u8,
        envvar: ?[]const u8 = null,
    },
};

pub const ParseError = error{
    UnknownOption,
    UnknownOptionAlias,
    UnknownSubcommand,
    MissingRequiredOption,
    MissingRequiredPositionalArgument,
    MissingSubcommand,
    MissingOptionValue,
    UnexpectedPositionalArgument,
    CommandDoesNotHavePositionalArguments,
} || Allocator.Error || value_parser.ValueParseError;

pub fn Parser(comptime Iterator: type) type {
    return struct {
        const Self = @This();

        alloc: Allocator,
        arg_iterator: Iterator,
        app: *const command.App,
        command_path: std.ArrayList(*const command.Command),
        position_argument_ix: usize = 0,
        next_arg: ?[]const u8 = null,
        global_options: *GlobalOptions,
        error_data: ?ErrorData = null,

        pub fn init(app: *const command.App, it: Iterator, alloc: Allocator) !Self {
            return .{
                .alloc = alloc,
                .arg_iterator = it,
                .app = app,
                .command_path = try std.ArrayList(*const command.Command).initCapacity(alloc, 16),
                .global_options = try GlobalOptions.init(app.help_config.color_usage, alloc),
            };
        }

        pub fn deinit(self: *Self) void {
            self.command_path.deinit();
            self.global_options.deinit();
        }

        inline fn current_command(self: *const Self) *const command.Command {
            return self.command_path.items[self.command_path.items.len - 1];
        }

        pub fn parse(self: *Self) ParseError!ParseResult {
            try self.command_path.append(&self.app.command);

            _ = self.nextArg();
            var args_only = false;
            while (self.nextArg()) |arg| {
                if (args_only) {
                    try self.handlePositionalArgument(arg);
                } else if (argp.interpret(arg)) |interpretation| {
                    args_only = try self.process_interpretation(&interpretation);
                } else |err| {
                    self.error_data = ErrorData{ .provided_string = arg };
                    return err;
                }
            }
            return self.finalize();
        }

        fn finalize(self: *Self) ParseError!ParseResult {
            for (self.command_path.items) |cmd| {
                if (cmd.options) |options| {
                    for (options) |*opt| {
                        try self.set_option_value_from_envvar(opt);
                        try opt.value_ref.finalize(self.alloc);

                        if (opt.required and opt.value_ref.element_count == 0) {
                            self.error_data = ErrorData{ .entity_name = opt.long_name };
                            return error.MissingRequiredOption;
                        }
                    }
                }
                switch (cmd.target) {
                    .action => |act| {
                        if (act.positional_args) |*pargs| {
                            const argh = PositionalArgsHelper{ .inner = pargs };
                            var it = argh.iterator();
                            const required_args_no = if (pargs.required) |req| req.len else 0;
                            while (it.next()) |parg| {
                                try parg.value_ref.finalize(self.alloc);

                                if (it.index <= required_args_no and parg.value_ref.element_count == 0) {
                                    self.error_data = ErrorData{ .entity_name = parg.name };
                                    return error.MissingRequiredPositionalArgument;
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
                    self.error_data = ErrorData{ .entity_name = self.current_command().name };
                    return error.MissingSubcommand;
                },
            }
        }

        fn handlePositionalArgument(self: *Self, arg: []const u8) ParseError!void {
            const cmd = self.current_command();
            switch (cmd.target) {
                .subcommands => {
                    self.error_data = ErrorData{ .entity_name = cmd.name };
                    return error.CommandDoesNotHavePositionalArguments;
                },
                .action => |act| {
                    if (act.positional_args) |*posArgs| {
                        var posH = PositionalArgsHelper{ .inner = posArgs };
                        if (self.position_argument_ix >= posH.len()) {
                            self.error_data = ErrorData{ .provided_string = arg };
                            return error.UnexpectedPositionalArgument;
                        }

                        const posArg = posH.at(self.position_argument_ix);
                        var posArgRef = posArg.value_ref;
                        posArgRef.put(arg, self.alloc) catch |err| {
                            self.error_data = ErrorData{
                                .invalid_value = .{
                                    .entity_type = .positional_argument,
                                    .entity_name = posArg.name,
                                    .provided_string = arg,
                                    .value_type = posArgRef.value_data.type_name,
                                },
                            };
                            return err;
                        };
                        if (posArgRef.value_type == .single) {
                            self.position_argument_ix += 1;
                        }
                    } else {
                        self.error_data = ErrorData{ .entity_name = cmd.name };
                        return error.CommandDoesNotHavePositionalArguments;
                    }
                },
            }
        }

        fn set_option_value_from_envvar(self: *Self, opt: *const command.Option) ParseError!void {
            if (opt.value_ref.element_count > 0) return;

            if (opt.envvar) |envvar_name| {
                if (std.process.getEnvVarOwned(self.alloc, envvar_name)) |value| {
                    defer self.alloc.free(value);
                    opt.value_ref.put(value, self.alloc) catch |err| {
                        self.error_data = ErrorData{ .invalid_value = .{
                            .entity_type = .option,
                            .entity_name = opt.long_name,
                            .provided_string = value,
                            .value_type = opt.value_ref.value_data.type_name,
                            .envvar = envvar_name,
                        } };
                        return err;
                    };
                } else |_| {}
            } else if (self.app.option_envvar_prefix) |prefix| {
                var envvar_name = try self.alloc.alloc(u8, opt.long_name.len + prefix.len);
                defer self.alloc.free(envvar_name);
                @memcpy(envvar_name[0..prefix.len], prefix);
                for (envvar_name[prefix.len..], opt.long_name) |*dest, name_char| {
                    dest.* = if (name_char == '-') '_' else std.ascii.toUpper(name_char);
                }

                if (std.process.getEnvVarOwned(self.alloc, envvar_name)) |value| {
                    defer self.alloc.free(value);
                    opt.value_ref.put(value, self.alloc) catch |err| {
                        self.error_data = ErrorData{ .invalid_value = .{
                            .entity_type = .option,
                            .entity_name = opt.long_name,
                            .provided_string = value,
                            .value_type = opt.value_ref.value_data.type_name,
                            .envvar = envvar_name,
                        } };
                        return err;
                    };
                } else |_| {}
            }
        }

        fn process_interpretation(self: *Self, int: *const argp.ArgumentInterpretation) ParseError!bool {
            var args_only = false;
            try switch (int.*) {
                .option => |opt| self.process_option(&opt),
                .double_dash => args_only = true,
                .other => |some_name| {
                    switch (self.current_command().target) {
                        .subcommands => |cmds| {
                            for (cmds) |*sc| {
                                if (std.mem.eql(u8, sc.name, some_name)) {
                                    try self.command_path.append(sc);
                                    return false;
                                }
                            }
                            self.error_data = ErrorData{ .provided_string = some_name };
                            return error.UnknownSubcommand;
                        },
                        .action => try self.handlePositionalArgument(some_name),
                    }
                },
            };
            return args_only;
        }

        fn nextArg(self: *Self) ?[]const u8 {
            if (self.next_arg) |arg| {
                self.next_arg = null;
                return arg;
            }
            return self.arg_iterator.next();
        }

        fn putArgBack(self: *Self, value: []const u8) void {
            std.debug.assert(self.next_arg == null);
            self.next_arg = value;
        }

        fn process_option(self: *Self, option_interpretation: *const argp.OptionInterpretation) ParseError!void {
            var opt: *const command.Option = switch (option_interpretation.option_type) {
                .long => try self.find_option_by_name(option_interpretation.name),
                .short => a: {
                    try self.set_concatenated_boolean_options(
                        self.current_command(),
                        option_interpretation.name[0 .. option_interpretation.name.len - 1],
                    );
                    break :a try self.find_option_by_alias(
                        self.current_command(),
                        option_interpretation.name[option_interpretation.name.len - 1],
                    );
                },
            };

            if (opt == self.global_options.option_show_help) {
                try help.print_command_help(self.app, try self.command_path.toOwnedSlice(), self.global_options);
                std.posix.exit(0);
            }

            if (opt.value_ref.value_data.is_bool) {
                if (option_interpretation.value) |opt_value| {
                    var lw = try self.alloc.alloc(u8, opt_value.len);
                    defer self.alloc.free(lw);

                    lw = std.ascii.lowerString(lw, opt_value);
                    try opt.value_ref.put(lw, self.alloc);
                    return;
                }

                if (self.nextArg()) |arg| {
                    if (arg.len > 0 and arg[0] != '-') {
                        var lw = try self.alloc.alloc(u8, arg.len);
                        defer self.alloc.free(lw);

                        lw = std.ascii.lowerString(lw, arg);
                        if (std.mem.eql(u8, lw, str_true) or std.mem.eql(u8, lw, str_false)) {
                            try opt.value_ref.put(lw, self.alloc);
                            return;
                        }
                    }
                    self.putArgBack(arg);
                }
                try opt.value_ref.put(str_true, self.alloc);
            } else {
                const arg = option_interpretation.value orelse self.nextArg() orelse {
                    self.error_data = ErrorData{ .entity_name = opt.long_name };
                    return error.MissingOptionValue;
                };
                opt.value_ref.put(arg, self.alloc) catch |err| {
                    self.error_data = ErrorData{ .invalid_value = .{
                        .entity_type = .option,
                        .entity_name = opt.long_name,
                        .provided_string = arg,
                        .value_type = opt.value_ref.value_data.type_name,
                    } };
                    return err;
                };
            }
        }

        fn find_option_by_name(self: *Self, option_name: []const u8) error{UnknownOption}!*const command.Option {
            for (0..self.command_path.items.len) |ix| {
                const cmd = self.command_path.items[self.command_path.items.len - ix - 1];
                if (cmd.options) |option_list| {
                    for (option_list) |*option| {
                        if (std.mem.eql(u8, option.long_name, option_name)) {
                            return option;
                        }
                    }
                }
            }
            for (self.global_options.options) |option| {
                if (std.mem.eql(u8, option.long_name, option_name)) {
                    return option;
                }
            }
            self.error_data = ErrorData{ .provided_string = option_name };
            return error.UnknownOption;
        }

        fn find_option_by_alias(self: *Self, cmd: *const command.Command, option_alias: u8) error{UnknownOptionAlias}!*const command.Option {
            if (option_alias == 'h') {
                return self.global_options.option_show_help;
            }
            if (cmd.options) |option_list| {
                for (option_list) |*option| {
                    if (option.short_alias) |alias| {
                        if (alias == option_alias) {
                            return option;
                        }
                    }
                }
            }
            self.error_data = ErrorData{ .option_alias = option_alias };
            return error.UnknownOptionAlias;
        }

        /// Set boolean options provided like `-acde`
        fn set_concatenated_boolean_options(self: *Self, cmd: *const command.Command, options: []const u8) ParseError!void {
            for (options) |alias| {
                var opt = try self.find_option_by_alias(cmd, alias);
                if (opt.value_ref.value_data.is_bool) {
                    opt.value_ref.put("true", self.alloc) catch unreachable;
                } else {
                    return error.MissingOptionValue;
                }
            }
        }
    };
}
