const std = @import("std");
const command = @import("command.zig");

const color_section = "33;1";
const color_options = "32";
const color_clear = "0";

pub fn print_command_help(current_command: *const command.Command, command_path: []const *const command.Command) !void {
    const stdout = std.io.getStdOut();
    var printer = Printer{
        .out = stdout.writer(),
        .has_tty = std.os.isatty(stdout.handle),
    };
    printer.printCommandHelp(current_command, command_path);
}

const Printer = struct {
    out: std.fs.File.Writer,
    has_tty: bool,

    inline fn write(self: *Printer, text: []const u8) void {
        _ = self.out.write(text) catch unreachable;
    }

    inline fn format(self: *Printer, comptime text: []const u8, args: anytype) void {
        std.fmt.format(self.out, text, args) catch unreachable;
    }

    inline fn printColor(self: *Printer, color: []const u8) void {
        if (self.has_tty)
            self.format("{c}[{s}m", .{ 0x1b, color });
    }
    inline fn printInColor(self: *Printer, color: []const u8, text: []const u8) void {
        self.printColor(color);
        self.write(text);
        self.printColor(color_clear);
    }

    inline fn printSpaces(self: *Printer, cnt: usize) void {
        var i: usize = 0;
        while (i < cnt) : (i += 1) {
            self.write(" ");
        }
    }

    fn printCommandHelp(self: *Printer, current_command: *const command.Command, command_path: []const *const command.Command) void {
        self.printInColor(color_section, "USAGE:");
        self.format("\n  ", .{});
        self.printColor(color_options);
        for (command_path) |cmd| {
            self.format("{s} ", .{cmd.name});
        }
        self.format("{s} [OPTIONS]\n", .{current_command.name});
        self.printColor(color_clear);

        self.format("\n{s}\n", .{current_command.help});
        if (current_command.description) |desc| {
            self.format("\n{s}\n", .{desc});
        }

        if (current_command.subcommands) |sc_list| {
            self.printInColor(color_section, "\nCOMMANDS:\n");

            var max_cmd_width: usize = 0;
            for (sc_list) |sc| {
                max_cmd_width = std.math.max(max_cmd_width, sc.name.len);
            }
            const cmd_column_width = max_cmd_width + 3;
            for (sc_list) |sc| {
                self.printColor(color_options);
                self.format("  {s}", .{sc.name});
                self.printColor(color_clear);
                var i: usize = 0;
                while (i < cmd_column_width - sc.name.len) {
                    self.write(" ");
                    i += 1;
                }

                self.format("{s}\n", .{sc.help});
            }
        }

        self.printInColor(color_section, "\nOPTIONS:\n");
        var option_column_width: usize = 7;
        if (current_command.options) |option_list| {
            var max_option_width: usize = 0;
            for (option_list) |option| {
                var w = option.long_name.len + option.value_name.len + 3;
                max_option_width = std.math.max(max_option_width, w);
            }
            option_column_width = max_option_width + 3;
            for (option_list) |option| {
                if (option.short_alias) |alias| {
                    self.printSpaces(2);
                    self.printColor(color_options);
                    self.format("-{c}", .{alias});
                    self.printColor(color_clear);
                    self.write(", ");
                } else {
                    self.printSpaces(6);
                }
                self.printColor(color_options);
                self.format("--{s}", .{option.long_name});
                self.printColor(color_clear);
                var width = option.long_name.len;
                if (option.value != .bool) {
                    self.printColor(color_options);
                    self.format(" <{s}>", .{option.value_name});
                    self.printColor(color_clear);
                    width += option.value_name.len + 3;
                }
                self.printSpaces(option_column_width - width);

                self.format("{s}\n", .{option.help});
            }
        }
        self.write("  ");
        self.printColor(color_options);
        self.write("-h");
        self.printColor(color_clear);
        self.write(", ");
        self.printColor(color_options);
        self.write("--help");
        self.printColor(color_clear);
        self.printSpaces(option_column_width - 4);
        self.format("Prints help information\n", .{});
    }
};
