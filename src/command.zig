const std = @import("std");
const Allocator = std.mem.Allocator;
const ArgIterator = std.process.ArgIterator;
const testing = std.testing;

pub const Command = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    usage: []const u8,
    flags: ?[]const *const Flag = null,
    subcommands: ?[]const *const Command = null,
    action: Action,

    fn find_subcommand(self: *const Command, subcommand_name: []u8) ?*const Command {
        if (self.subcommands) |sc_list| {
            for (sc_list) |sc| {
                if (std.mem.eql(u8, sc.name, subcommand_name)) {
                    return sc;
                }
            }
        }
        return null;
    }
    fn find_flag_by_name(self: *const Command, flag_name: []u8) ?*const Flag {
        if (self.flags) |flag_list| {
            for (flag_list) |flag| {
                if (std.mem.eql(u8, flag.name, flag_name)) {
                    return flag;
                }
            }
        }
        return null;
    }
    fn find_flag_by_alias(self: *const Command, flag_alias: u8) ?*const Flag {
        if (self.flags) |flag_list| {
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
};

pub const CapturedFlag = struct {
  flag: *const Flag,
  value: ?[]u8,
};

pub const CalledCommand = struct {
    command: *const Command,
    captured_flags: ?[]CapturedFlag = null,
    parent: ?*const CalledCommand = null,
};

const CommandRun = struct {
    alloc: Allocator,
    arg_iterator: *ArgIterator,
    current_command: *CalledCommand,

    const Self = @This();

    const ArgParseResult = union(enum) {
        command: *const Command,
        flag: *const Flag,
        arg: []u8,
    };

    fn parse(self: *Self) anyerror!void {
        _ = self.arg_iterator.next(self.alloc);
        const arg_opt = self.arg_iterator.next(self.alloc);
        if (arg_opt) |arg| {
            var b = try arg;
            var a = self.parse_arg(b);
            std.log.info("command: {s}, arg[1]={}", .{ self.current_command.command.name, a.?.command });
        } else {
            std.log.info("end", .{});
        }
    }

    fn parse_arg(self: *const Self, arg: []u8) ?ArgParseResult {
        if (arg.len == 0) return null;
        if (arg[0] == '-') {
            if (arg.len == 1) return ArgParseResult{ .arg = arg };
            if (arg[1] == '-') {
                // Long flag
                if (arg.len == 2) {
                    return ArgParseResult{ .arg = arg };
                } else if (self.current_command.command.find_flag_by_name(arg[2..])) |flag| {
                    return ArgParseResult{ .flag = flag };
                } else {
                    return null;
                }
            } else {
                // Short flag
            }
            unreachable;
        } else if (self.current_command.command.find_subcommand(arg)) |sc| {
            return ArgParseResult{ .command = sc };
        } else {
            return null;
        }
    }
};

pub const Action = fn (*const CalledCommand) anyerror!void;

pub const Flag = struct {
    name: []const u8,
    one_char_alias: ?u8 = null,
    usage: []const u8,
    required: bool = false,

    pub fn get_string(_: *Flag) ?[]const u8 {
        return null;
    }
};

pub fn run(cmd: *const Command, alloc: Allocator) anyerror!void {
    var it = std.process.args();
    var cc = CalledCommand {
      .command = cmd,
    };
    var cr = CommandRun {
      .alloc = alloc,
      .arg_iterator = &it,
      .current_command = &cc,
    };
    return cr.parse();
}
