const std = @import("std");
const command = @import("command.zig");
const parser = @import("./parser.zig");
const Printer = @import("Printer.zig");
const value_ref = @import("value_ref.zig");
const GlobalOptions = @import("GlobalOptions.zig");
const PositionalArgsHelper = @import("PositionalArgsHelper.zig");
const Allocator = std.mem.Allocator;

const color_clear = "0";

pub fn print_command_help(
    printer: *Printer,
    app: *const command.App,
    command_path: []const *const command.Command,
    global_options: *const GlobalOptions,
) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    defer printer.flush();
    var help_printer = HelpPrinter{
        .app = app,
        .printer = printer,
        .global_options = global_options,
        .allocator = arena.allocator(),
    };

    if (command_path.len == 1) {
        help_printer.printAppHelp(app, command_path);
    } else {
        help_printer.printCommandHelp(command_path);
    }
}

const HelpPrinter = struct {
    app: *const command.App,
    printer: *Printer,
    global_options: *const GlobalOptions,
    allocator: Allocator,

    fn printAppHelp(self: *HelpPrinter, app: *const command.App, command_path: []const *const command.Command) void {
        self.printer.printColor(self.app.help_config.color_app_name);
        self.printer.format("{s}\n", .{app.command.name});
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
        self.printer.printInColor(self.app.help_config.color_section, "USAGE:");
        self.printer.format("\n  ", .{});
        self.printer.printColor(self.app.help_config.color_option);
        for (command_path) |cmd| {
            self.printer.format("{s} ", .{cmd.name});
        }
        const cmd = command_path[command_path.len - 1];
        self.printer.format("[OPTIONS]", .{});
        switch (cmd.target) {
            .action => |act| {
                if (act.positional_args) |pargs| {
                    if (pargs.required) |req| {
                        for (req) |*parg| {
                            self.printer.write(" ");
                            self.printer.format("<{s}>", .{parg.name});
                            if (parg.value_ref.value_type == value_ref.ValueType.multi) {
                                self.printer.write("...");
                            }
                        }
                    }
                    if (pargs.optional) |opt| {
                        for (opt) |*parg| {
                            self.printer.write(" ");
                            self.printer.write("[");
                            self.printer.format("<{s}>", .{parg.name});
                            if (parg.value_ref.value_type == value_ref.ValueType.multi) {
                                self.printer.write("...");
                            }
                            self.printer.write("]");
                        }
                    }
                }
            },
            .subcommands => {},
        }
        self.printer.printNewLine();
        self.printer.printColor(color_clear);

        if (cmd.description) |desc| {
            self.printer.format("\n{s}\n", .{desc.one_line});
            if (desc.detailed) |det| {
                self.printer.format("\n{s}\n", .{det});
            }
        }

        switch (cmd.target) {
            .action => |act| {
                if (act.positional_args) |*pargs| {
                    self.printer.printInColor(self.app.help_config.color_section, "\nARGUMENTS:\n");
                    var max_arg_width: usize = 0;
                    const arg_h = PositionalArgsHelper{ .inner = pargs };
                    var it = arg_h.iterator();
                    while (it.next()) |parg| {
                        max_arg_width = @max(max_arg_width, parg.name.len);
                    }
                    it.index = 0;
                    while (it.next()) |parg| {
                        self.printer.write("  ");
                        self.printer.printInColor(self.app.help_config.color_option, parg.name);
                        if (parg.help) |help| {
                            self.printer.printSpaces(max_arg_width - parg.name.len + 3);
                            self.printer.write(help);
                        }
                        self.printer.printNewLine();
                    }
                }
            },
            .subcommands => |sc_list| {
                self.printer.printInColor(self.app.help_config.color_section, "\nCOMMANDS:\n");

                var max_cmd_width: usize = 0;
                for (sc_list) |sc| {
                    max_cmd_width = @max(max_cmd_width, sc.name.len);
                }
                const cmd_column_width = max_cmd_width + 3;
                for (sc_list) |sc| {
                    self.printer.printColor(self.app.help_config.color_option);
                    self.printer.format("  {s}", .{sc.name});
                    self.printer.printColor(color_clear);
                    if (sc.description) |desc| {
                        var i: usize = 0;
                        while (i < cmd_column_width - sc.name.len) {
                            self.printer.write(" ");
                            i += 1;
                        }

                        self.printer.format("{s}", .{desc.one_line});
                    }
                    self.printer.printNewLine();
                }
            },
        }

        self.printer.printInColor(self.app.help_config.color_section, "\nOPTIONS:\n");
        var option_column_width: usize = 7;
        if (cmd.options) |option_list| {
            for (option_list) |option| {
                const w = option.long_name.len + option.value_name.len + 3;
                option_column_width = @max(option_column_width, w);
            }
        }
        for (self.global_options.options) |option| {
            const w = option.long_name.len + option.value_name.len + 3;
            option_column_width = @max(option_column_width, w);
        }
        option_column_width += 3;
        if (cmd.options) |option_list| {
            for (option_list) |*option| {
                self.printOption(option, option_column_width);
            }
        }
        for (self.global_options.options) |option| {
            self.printOption(option, option_column_width);
        }
    }

    fn printOption(self: *HelpPrinter, option: *const command.Option, option_column_width: usize) void {
        if (option.short_alias) |alias| {
            self.printer.printSpaces(2);
            self.printer.printColor(self.app.help_config.color_option);
            self.printer.format("-{c}", .{alias});
            self.printer.printColor(color_clear);
            self.printer.write(", ");
        } else {
            self.printer.printSpaces(6);
        }
        self.printer.printColor(self.app.help_config.color_option);
        self.printer.format("--{s}", .{option.long_name});
        self.printer.printColor(color_clear);
        var width = option.long_name.len;
        if (!option.value_ref.value_data.is_bool) {
            self.printer.printColor(self.app.help_config.color_option);
            self.printer.format(" <{s}>", .{option.value_name});
            self.printer.printColor(color_clear);
            width += option.value_name.len + 3;
        }

        // print option help
        self.printer.printSpaces(option_column_width - width);
        var it = std.mem.splitScalar(u8, option.help, '\n');
        var lineNo: usize = 0;
        while (it.next()) |line| : (lineNo += 1) {
            if (lineNo > 0) {
                self.printer.printNewLine();
                self.printer.printSpaces(option_column_width + 8);
            }
            self.printer.write(line);
        }
        const envvar = parser.getEnvvarName(
            option,
            self.app.option_envvar_prefix,
            self.allocator,
        ) catch unreachable;
        if (envvar) |ev| {
            self.printer.format(" [env: {s}]", .{ev});
        }
        self.printer.printNewLine();
    }
};
