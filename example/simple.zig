const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var ip_option = cli.Option{
    .name = "ip",
    .help = "this is the IP address",
    .value = cli.OptionValue{ .string = null },
};
var int_option = cli.Option{
    .name = "int",
    .help = "this is an int",
    .value = cli.OptionValue{ .int = null },
};
var bool_option = cli.Option{
    .name = "bool",
    .help = "this is a bool",
    .value = cli.OptionValue{ .bool = false },
};
var float_option = cli.Option{
                .name = "float",
                .help = "this is a float",
                .value = cli.OptionValue{ .float = 0.34 },
            };

var name_option = cli.Option{
                    .name = "name",
                    .help = "name help",
                    .value = cli.OptionValue{ .string = null },
                };
var app = &cli.Command{
    .name = "abc",
    .help = "this is a test command",
    .subcommands = &.{&cli.Command{
        .name = "sub1",
        .help = "it's a try",
        .description = 
            \\this is my awesome multiline description.
            \\This is already line 2.
            \\And this is line 3.
            ,
        .options = &.{
            &ip_option,
            &int_option,
            &bool_option,
            &float_option,
        },
        .subcommands = &.{
            &cli.Command{
                .name = "sub2",
                .help = "sub2 help",
                .options = &.{&name_option},
                .action = run_sub2,
            },
        },
        .action = run_sub1,
    }},
    .action = run_main,
};

pub fn main() anyerror!void {
    return cli.run(app, allocator);
}

fn run_main(_: ?[]const []const u8) anyerror!void {
    std.log.debug("running main", .{});
}

fn run_sub1(_: ?[]const []const u8) anyerror!void {
    std.log.debug("running sub1: ip=", .{});
}

fn run_sub2(_: ?[]const []const u8) anyerror!void {
    var ip = ip_option.value.string.?;
    std.log.debug("running sub2: ip={s}, bool={}, float={}", .{ ip, bool_option.value.bool, float_option.value.float });
}
