const std = @import("std");
const command = @import("command.zig");
const Printer = @import("Printer.zig");

const color_section = "33;1";
const color_options = "32";
const color_clear = "0";

pub fn print_command_help(current_command: *const command.Command, command_path: []const *const command.Command) !void {
    const stdout = std.io.getStdOut();
    var help_printer = HelpPrinter{
        .printer = Printer.init(stdout),
    };
    help_printer.printCommandHelp(current_command, command_path);
}

const HelpPrinter = struct {
    printer: Printer,

    fn printCommandHelp(self: *HelpPrinter, current_command: *const command.Command, command_path: []const *const command.Command) void {
        self.printer.printInColor(color_section, "USAGE:");
        self.printer.format("\n  ", .{});
        self.printer.printColor(color_options);
        for (command_path) |cmd| {
            self.printer.format("{s} ", .{cmd.name});
        }
        self.printer.format("{s} [OPTIONS]\n", .{current_command.name});
        self.printer.printColor(color_clear);

        self.printer.format("\n{s}\n", .{current_command.help});
        if (current_command.description) |desc| {
            self.printer.format("\n{s}\n", .{desc});
        }

        if (current_command.subcommands) |sc_list| {
            self.printer.printInColor(color_section, "\nCOMMANDS:\n");

            var max_cmd_width: usize = 0;
            for (sc_list) |sc| {
                max_cmd_width = std.math.max(max_cmd_width, sc.name.len);
            }
            const cmd_column_width = max_cmd_width + 3;
            for (sc_list) |sc| {
                self.printer.printColor(color_options);
                self.printer.format("  {s}", .{sc.name});
                self.printer.printColor(color_clear);
                var i: usize = 0;
                while (i < cmd_column_width - sc.name.len) {
                    self.printer.write(" ");
                    i += 1;
                }

                self.printer.format("{s}\n", .{sc.help});
            }
        }

        self.printer.printInColor(color_section, "\nOPTIONS:\n");
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
                    self.printer.printSpaces(2);
                    self.printer.printColor(color_options);
                    self.printer.format("-{c}", .{alias});
                    self.printer.printColor(color_clear);
                    self.printer.write(", ");
                } else {
                    self.printer.printSpaces(6);
                }
                self.printer.printColor(color_options);
                self.printer.format("--{s}", .{option.long_name});
                self.printer.printColor(color_clear);
                var width = option.long_name.len;
                if (option.value != .bool) {
                    self.printer.printColor(color_options);
                    self.printer.format(" <{s}>", .{option.value_name});
                    self.printer.printColor(color_clear);
                    width += option.value_name.len + 3;
                }
                self.printer.printSpaces(option_column_width - width);

                self.printer.format("{s}\n", .{option.help});
            }
        }
        self.printer.write("  ");
        self.printer.printColor(color_options);
        self.printer.write("-h");
        self.printer.printColor(color_clear);
        self.printer.write(", ");
        self.printer.printColor(color_options);
        self.printer.write("--help");
        self.printer.printColor(color_clear);
        self.printer.printSpaces(option_column_width - 4);
        self.printer.format("Prints help information\n", .{});
    }
};
