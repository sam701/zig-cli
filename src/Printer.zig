const std = @import("std");
const command = @import("./command.zig");

const Self = @This();

out: std.fs.File.Writer,
use_color: bool,

const color_clear = "0";

pub fn init(file: std.fs.File, color: command.ColorUsage) Self {
    return .{
        .out = file.writer(),
        .use_color = switch (color) {
            .always => true,
            .never => false,
            .auto => std.posix.isatty(file.handle),
        },
    };
}

pub inline fn write(self: *const Self, text: []const u8) void {
    _ = self.out.write(text) catch unreachable;
}

pub inline fn printNewLine(self: *Self) void {
    self.write("\n");
}

pub inline fn format(self: *const Self, comptime text: []const u8, args: anytype) void {
    std.fmt.format(self.out, text, args) catch unreachable;
}

pub inline fn printColor(self: *const Self, color: []const u8) void {
    if (self.use_color)
        self.format("{c}[{s}m", .{ 0x1b, color });
}

pub inline fn printInColor(self: *const Self, color: []const u8, text: []const u8) void {
    self.printColor(color);
    self.write(text);
    self.printColor(color_clear);
}

pub inline fn printSpaces(self: *const Self, cnt: usize) void {
    var i: usize = 0;
    while (i < cnt) : (i += 1) {
        self.write(" ");
    }
}
