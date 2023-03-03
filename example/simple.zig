const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var ip_option = cli.Option{
    .long_name = "ip",
    .help = "this is the IP address",
    .short_alias = 'i',
    .value = cli.OptionValue{ .string = null },
    .required = true,
    .value_name = "IP",
};
var int_option = cli.Option{
    .long_name = "int",
    .help = "this is an int",
    .value = cli.OptionValue{ .int = null },
};
var bool_option = cli.Option{
    .long_name = "bool",
    .short_alias = 'b',
    .help = "this is a bool",
    .value = cli.OptionValue{ .bool = false },
};
var float_option = cli.Option{
    .long_name = "float",
    .help = "this is a float",
    .value = cli.OptionValue{ .float = 0.34 },
};

var name_option = cli.Option{
    .long_name = "long_name",
    .help = "long_name help",
    .value = cli.OptionValue{ .string = null },
};
var app = &cli.App{
    .name = "simple",
    .description = "This a simple CLI app\nEnjoy!",
    .version = "0.10.3",
    .author = "sam701 & contributors",
    .subcommands = &.{&cli.Command{
        .name = "sub1",
        .help = "another awesome command",
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
                .action = run_sub2,
            },
        },
    }},
};

pub fn main() anyerror!void {
    return cli.run(app, allocator);
}

fn run_sub2(args: []const []const u8) anyerror!void {
    var ip = ip_option.value.string.?;
    std.log.debug("running sub2: ip={s}, bool={any}, float={any} arg_count={any}", .{ ip, bool_option.value.bool, float_option.value.float, args.len });
}
