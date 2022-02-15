const std = @import("std");
const command = @import("command.zig");
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;

const help_flag = &command.Flag {
    .name = "help",
    .help = "Show this help output.",
    .one_char_alias = 'h',
    .value_type = .bool,
};

const Parser = struct {
    alloc: Allocator,
    arg_iterator: *ArgIterator,
    current_command: *const command.Command,
    command_path: std.ArrayList(*const command.Command),
    captured_flags: std.ArrayList(command.CapturedFlag),
    captured_arguments: std.ArrayList([]const u8),

    const Self = @This();

    const ArgParseResult = union(enum) {
        command: *const command.Command,
        flag: *const command.Flag,
        arg: []u8,
    };

    fn init(cmd: *const command.Command, it: *ArgIterator, alloc: Allocator) !*Self {
        var s = try alloc.create(Parser);
        s.alloc = alloc;
        s.arg_iterator = it;
        s.current_command = cmd;
        s.command_path = try std.ArrayList(*const command.Command).initCapacity(alloc, 16);
        s.captured_flags = try std.ArrayList(command.CapturedFlag).initCapacity(alloc, 16);
        s.captured_arguments = try std.ArrayList([]const u8).initCapacity(alloc, 16);
        return s;
    }

    fn deinit(self: *Self) void {
        self.captured_flags.deinit();
        self.captured_arguments.deinit();
        self.command_path.deinit();
        self.alloc.destroy(self);
    }

    fn parse(self: *Self) anyerror!ParseResult {
        _ = self.arg_iterator.next(self.alloc);
        while (self.arg_iterator.next(self.alloc)) |arg| {
            var b = try arg;
            if (self.parse_arg(b)) |parsed_arg| {
                try self.process_arg(parsed_arg);
            }
        }
        var flags = self.captured_flags.toOwnedSlice();
        var args = self.captured_arguments.toOwnedSlice();
        return ParseResult{ .action = self.current_command.action, .ctx = command.Context{
            .flags = flags,
            .args = args,
        } };
    }

    fn process_arg(self: *Self, arg: ArgParseResult) !void {
        switch (arg) {
            .command => |cmd| {
                try self.command_path.append(self.current_command);
                self.current_command = cmd;
            },
            .flag => |flag| {
                try self.add_flag(flag);
            },
            .arg => unreachable,
        }
    }

    fn add_flag(self: *Self, flag: *const command.Flag) !void {
        if (flag == help_flag) {
            print_command_help(self.current_command, self.command_path.toOwnedSlice());
            std.os.exit(0);
            unreachable;
        }

        var val: command.FlagValue = undefined;
        if (flag.value_type == .bool) {
            val = command.FlagValue{ .bool = true };
        } else {
            if (self.arg_iterator.next(self.alloc)) |arg| {
                var str = try arg;
                switch (flag.value_type) {
                    .bool => unreachable,
                    .string => {
                        val = command.FlagValue{ .string = str };
                    },
                    .int => {
                        if (std.fmt.parseInt(i64, str, 10)) |iv| {
                            val = command.FlagValue{ .int = iv };
                        } else |_| {
                            try std.fmt.format(std.io.getStdErr().writer(), "ERROR: flag({s}): cannot parse int value\n", .{flag.name});
                            std.os.exit(10);
                            unreachable;
                        }
                    },
                    .float => {
                        if (std.fmt.parseFloat(f64, str)) |fv| {
                            val = command.FlagValue{ .float = fv };
                        } else |_| {
                            try std.fmt.format(std.io.getStdErr().writer(), "ERROR: flag({s}): cannot parse flaot value\n", .{flag.name});
                            std.os.exit(10);
                            unreachable;
                        }
                    },
                }
            } else {
                try std.fmt.format(std.io.getStdErr().writer(), "ERROR: missing argument for {s}\n", .{flag.name});
                std.os.exit(10);
                unreachable;
            }
        }

        try self.captured_flags.append(command.CapturedFlag{
            .flag = flag,
            .value = val,
        });
    }

    fn parse_arg(self: *const Self, arg: []u8) ?ArgParseResult {
        if (arg.len == 0) return null;
        if (arg[0] == '-') {
            if (arg.len == 1) return ArgParseResult{ .arg = arg };
            if (arg[1] == '-') {
                // Long flag
                if (arg.len == 2) {
                    return ArgParseResult{ .arg = arg };
                } else if (find_flag_by_name(self.current_command, arg[2..])) |flag| {
                    return ArgParseResult{ .flag = flag };
                } else {
                    std.fmt.format(std.io.getStdErr().writer(), "ERROR: unknown flag {s}\n", .{arg}) catch unreachable;
                    std.os.exit(10);
                    unreachable;
                }
            } else {
                // TODO: Short flag
            }
            unreachable;
        } else if (find_subcommand(self.current_command, arg)) |sc| {
            return ArgParseResult{ .command = sc };
        } else {
            return null;
        }
    }


};

const ParseResult = struct {
    action: command.Action,
    ctx: command.Context,
};

pub fn run(cmd: *const command.Command, alloc: Allocator) anyerror!void {
    var it = std.process.args();
    var cr = try Parser.init(cmd, &it, alloc);
    var result = try cr.parse();
    cr.deinit();
    it.deinit();

    return result.action(&result.ctx);
}

fn find_subcommand(cmd: *const command.Command, subcommand_name: []u8) ?*const command.Command {
    if (cmd.subcommands) |sc_list| {
        for (sc_list) |sc| {
            if (std.mem.eql(u8, sc.name, subcommand_name)) {
                return sc;
            }
        }
    }
    return null;
}
fn find_flag_by_name(cmd: *const command.Command, flag_name: []u8) ?*const command.Flag {
    if (std.mem.eql(u8, "help", flag_name)) {
        return help_flag;
    }
    if (cmd.flags) |flag_list| {
        for (flag_list) |flag| {
            if (std.mem.eql(u8, flag.name, flag_name)) {
                return flag;
            }
        }
    }
    return null;
}
fn find_flag_by_alias(cmd: *const command.Command, flag_alias: u8) ?*const command.Flag {
    if (cmd.flags) |flag_list| {
        for (flag_list) |flag| {
            if (flag.one_char_alias) |alias| {
                if (alias == flag_alias) {
                    return flag;
                }
            }
        }
    }
    return null;
}

fn print_command_help(current_command: *const command.Command, command_path: []const *const command.Command) void {
    var out = std.io.getStdOut().writer();
    std.fmt.format(out, "Usage: ", .{}) catch unreachable;
    for (command_path) |cmd| {
        std.fmt.format(out, "{s} ", .{cmd.name}) catch unreachable;
    }
    std.fmt.format(out, "{s}\n\n{s}\n", .{
        current_command.name,
        current_command.help,
    }) catch unreachable;

    if (current_command.description) |desc| {
        std.fmt.format(out, "\n{s}\n", .{desc}) catch unreachable;
    }

    if (current_command.subcommands) |sc_list| {
        std.fmt.format(out, "\nCommands:\n", .{}) catch unreachable;

        var max_cmd_width:usize = 0;
        for (sc_list) |sc| {
            max_cmd_width = std.math.max(max_cmd_width, sc.name.len);
        }
        const cmd_column_width = max_cmd_width + 3;
        for (sc_list) |sc| {
            std.fmt.format(out, "  {s}", .{sc.name}) catch unreachable;
            var i: usize = 0;
            while (i < cmd_column_width - sc.name.len) {
                std.fmt.format(out, " ", .{}) catch unreachable;
                i+=1;
            }

            std.fmt.format(out, "{s}\n", .{sc.help}) catch unreachable;
        }
    }

    if(current_command.flags) |flag_list| {
        std.fmt.format(out, "\nFlags:\n", .{}) catch unreachable;

        var max_flag_width:usize = 0;
        for (flag_list) |flag| {
            max_flag_width = std.math.max(max_flag_width, flag.name.len);
        }
        const flag_column_width = max_flag_width + 3;
        for (flag_list) |flag| {
            std.fmt.format(out, "  --{s}", .{flag.name}) catch unreachable;
            var i: usize = 0;
            while (i < flag_column_width - flag.name.len) {
                std.fmt.format(out, " ", .{}) catch unreachable;
                i+=1;
            }

            std.fmt.format(out, "{s}\n", .{flag.help}) catch unreachable;
        }
    }
}