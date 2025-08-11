const std = @import("std");
const command = @import("./command.zig");

const Self = @This();

writer: *std.Io.Writer,
use_color: bool,

const color_clear = "0";

pub fn init(writer: *std.Io.Writer, use_color: bool) Self {
    return .{
        .writer = writer,
        .use_color = use_color,
    };
}

pub fn flush(self: *Self) void {
    self.writer.flush() catch unreachable;
}

pub inline fn write(self: *Self, text: []const u8) void {
    _ = self.writer.writeAll(text) catch unreachable;
}

pub inline fn printNewLine(self: *Self) void {
    self.writer.writeByte('\n') catch unreachable;
}

pub inline fn format(self: *Self, comptime fmt: []const u8, args: anytype) void {
    self.writer.print(fmt, args) catch unreachable;
}

pub inline fn printColor(self: *Self, color: []const u8) void {
    if (self.use_color)
        self.format("{c}[{s}m", .{ 0x1b, color });
}

pub inline fn printInColor(self: *Self, color: []const u8, text: []const u8) void {
    self.printColor(color);
    self.write(text);
    self.printColor(color_clear);
}

pub inline fn printSpaces(self: *Self, cnt: usize) void {
    self.writer.splatByteAll(' ', cnt) catch unreachable;
}
