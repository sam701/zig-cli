const std = @import("std");
const command = @import("command.zig");
const Printer = @import("Printer.zig");

const color_clear = "0";

pub fn print_command_help(app: *const command.App, command_path: []const *const command.Command) !void {
    const stdout = std.io.getStdOut();
    var help_printer = HelpPrinter{
        .printer = Printer.init(stdout, app.help_config.color_usage),
        .help_config = &app.help_config,
    };
    if (command_path.len == 1) {
        help_printer.printAppHelp(app, command_path);
    } else {
        help_printer.printCommandHelp(command_path);
    }
}

const HelpPrinter = struct {
    printer: Printer,
    help_config: *const command.HelpConfig,

    fn printAppHelp(self: *HelpPrinter, app: *const command.App, command_path: []const *const command.Command) void {
        self.printer.printColor(self.help_config.color_app_name);
        self.printer.format("{s}\n", .{app.name});
        self.printer.printColor(color_clear);
        if (app.version) |v| {
            self.printer.format("Version: {s}\n", .{v});
        }
        if (app.author) |a| {
            self.printer.format("Author: {s}\n", .{a});
        }
        self.printer.write("\n");

        self.printCommandHelp(command_path);
    }

    fn printCommandHelp(self: *HelpPrinter, command_path: []const *const command.Command) void {
        self.printer.printInColor(self.help_config.color_section, "USAGE:");
        self.printer.format("\n  ", .{});
        self.printer.printColor(self.help_config.color_option);
        for (command_path) |cmd| {
            self.printer.format("{s} ", .{cmd.name});
        }
        var current_command = command_path[command_path.len - 1];
        self.printer.format("[OPTIONS]\n", .{});
        self.printer.printColor(color_clear);

        if (command_path.len > 1) {
            self.printer.format("\n{s}\n", .{current_command.help});
        }
        if (current_command.description) |desc| {
            self.printer.format("\n{s}\n", .{desc});
        }

        if (current_command.subcommands) |sc_list| {
            self.printer.printInColor(self.help_config.color_section, "\nCOMMANDS:\n");

            var max_cmd_width: usize = 0;
            for (sc_list) |sc| {
                max_cmd_width = @max(max_cmd_width, sc.name.len);
            }
            const cmd_column_width = max_cmd_width + 3;
            for (sc_list) |sc| {
                self.printer.printColor(self.help_config.color_option);
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

        self.printer.printInColor(self.help_config.color_section, "\nOPTIONS:\n");
        var option_column_width: usize = 7;
        if (current_command.options) |option_list| {
            var max_option_width: usize = 0;
            for (option_list) |option| {
                var w = option.long_name.len + option.value_name.len + 3;
                max_option_width = @max(max_option_width, w);
            }
            option_column_width = max_option_width + 3;
            for (option_list) |option| {
                if (option.short_alias) |alias| {
                    self.printer.printSpaces(2);
                    self.printer.printColor(self.help_config.color_option);
                    self.printer.format("-{c}", .{alias});
                    self.printer.printColor(color_clear);
                    self.printer.write(", ");
                } else {
                    self.printer.printSpaces(6);
                }
                self.printer.printColor(self.help_config.color_option);
                self.printer.format("--{s}", .{option.long_name});
                self.printer.printColor(color_clear);
                var width = option.long_name.len;
                if (!option.value_ref.value_data.is_bool) {
                    self.printer.printColor(self.help_config.color_option);
                    self.printer.format(" <{s}>", .{option.value_name});
                    self.printer.printColor(color_clear);
                    width += option.value_name.len + 3;
                }
                self.printer.printSpaces(option_column_width - width);

                self.printer.format("{s}\n", .{option.help});
            }
        }
        self.printer.write("  ");
        self.printer.printColor(self.help_config.color_option);
        self.printer.write("-h");
        self.printer.printColor(color_clear);
        self.printer.write(", ");
        self.printer.printColor(self.help_config.color_option);
        self.printer.write("--help");
        self.printer.printColor(color_clear);
        self.printer.printSpaces(option_column_width - 4);
        self.printer.format("Prints help information\n", .{});
    }
};
