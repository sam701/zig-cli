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

  // pub fn string_flag(self: *Context, flag: *const Flag) ?[]const u8 {
  //   unreachable;
  // }
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

    pub fn get_string(_: *Flag) ?[]const u8 {
      // TODO
        return null;
    }
};