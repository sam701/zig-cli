const std = @import("std");

pub const Command = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    usage: []const u8,
    flags: ?[]const *const Flag = null,
    subcommands: ?[]const *const Command = null,
    action: Action,
};

pub const CapturedFlag = struct {
    flag: *const Flag,
    value: FlagValue,
};

pub const Context = struct {
    flags: []const CapturedFlag,
    args: []const []const u8,

    fn find_flag(self: *const Context, flag: *const Flag) ?*const CapturedFlag {
        for (self.flags) |_, ix| {
            const f = self.flags[self.flags.len - 1 - ix];
            if (f.flag == flag) {
                return &f;
            }
        }
        return null;
    }

    pub fn string_flag_value(self: *const Context, comptime flag: *const Flag) ?[]const u8 {
        if (flag.value_type != .string) @compileError("Flag value type is not string");
        if (self.find_flag(flag)) |cf| {
            return cf.value.string;
        }
        return null;
    }

    pub fn is_flag_set(self: *const Context, comptime flag: *const Flag) bool {
        if (flag.value_type != .bool) @compileError("Flag value type is not bool");
        return self.find_flag(flag) != null;
    }
};

pub const Action = fn (*const Context) anyerror!void;

pub const FlagValueType = enum {
    bool,
    string,
    int,
    float,
};

pub const FlagValue = union(FlagValueType) {
    bool: bool,
    string: []u8,
    int: i64,
    float: f64,
};

pub const Flag = struct {
    name: []const u8,
    one_char_alias: ?u8 = null,
    usage: []const u8,
    required: bool = false,
    value_type: FlagValueType,
    // TODO: support value lists
};
