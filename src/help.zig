const std = @import("std");
const command = @import("command.zig");

pub fn print_command_help(current_command: *const command.Command, command_path: []const *const command.Command) !void {
    var out = std.io.getStdOut().writer();
    try std.fmt.format(out, "USAGE:\n  ", .{});
    for (command_path) |cmd| {
        try std.fmt.format(out, "{s} ", .{cmd.name});
    }
    try std.fmt.format(out, "{s} [OPTIONS]\n\n{s}\n", .{
        current_command.name,
        current_command.help,
    });

    if (current_command.description) |desc| {
        try std.fmt.format(out, "\n{s}\n", .{desc});
    }

    if (current_command.subcommands) |sc_list| {
        try std.fmt.format(out, "\nCOMMANDS:\n", .{});

        var max_cmd_width: usize = 0;
        for (sc_list) |sc| {
            max_cmd_width = std.math.max(max_cmd_width, sc.name.len);
        }
        const cmd_column_width = max_cmd_width + 3;
        for (sc_list) |sc| {
            try std.fmt.format(out, "  {s}", .{sc.name});
            var i: usize = 0;
            while (i < cmd_column_width - sc.name.len) {
                try std.fmt.format(out, " ", .{});
                i += 1;
            }

            try std.fmt.format(out, "{s}\n", .{sc.help});
        }
    }

    try std.fmt.format(out, "\nOPTIONS:\n", .{});
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
                try print_spaces(out, 2);
                try std.fmt.format(out, "-{c}, ", .{alias});
            } else {
                try print_spaces(out, 6);
            }
            try std.fmt.format(out, "--{s}", .{option.long_name});
            var width = option.long_name.len;
            if (option.value != .bool) {
                try std.fmt.format(out, " <{s}>", .{option.value_name});
                width += option.value_name.len + 3;
            }
            try print_spaces(out, option_column_width - width);

            try std.fmt.format(out, "{s}\n", .{option.help});
        }
    }
    try std.fmt.format(out, "  -h, --help", .{});
    try print_spaces(out, option_column_width - 4);
    try std.fmt.format(out, "Prints help information\n", .{});
}

fn print_spaces(out: std.fs.File.Writer, cnt: usize) !void {
    var i: usize = 0;
    while (i < cnt) : (i += 1) {
        try std.fmt.format(out, " ", .{});
    }
}
