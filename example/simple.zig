const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var config = struct {
    ip: []const u8 = undefined,
    int: i32 = undefined,
    bool: bool = false,
    float: f64 = 0.34,
}{};

var ip_option = cli.Option{
    .long_name = "ip",
    .help = "this is the IP address",
    .short_alias = 'i',
    .value_ref = cli.mkRef(&config.ip),
    .required = true,
    .value_name = "IP",
};
var int_option = cli.Option{
    .long_name = "int",
    .help = "this is an int",
    .value_ref = cli.mkRef(&config.int),
};
var bool_option = cli.Option{
    .long_name = "bool",
    .short_alias = 'b',
    .help = "this is a bool",
    .value_ref = cli.mkRef(&config.bool),
};
var float_option = cli.Option{
    .long_name = "float",
    .help = "this is a float",
    .value_ref = cli.mkRef(&config.float),
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

fn run_sub2() anyerror!void {
    const c = &config;
    std.log.debug("running sub2: ip={s}, bool={any}, float={any}", .{ c.ip, c.bool, c.float });
}
