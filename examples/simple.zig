const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var config = struct {
    ip: []const u8 = undefined,
    int: i32 = undefined,
    bool: bool = false,
    float: f64 = 0.34,
    arg1: u64 = 0,
    arg2: []const []const u8 = undefined,
}{};

fn sub3(r: *cli.AppRunner) !cli.Command {
    return cli.Command{
        .name = "sub3",
        .description = cli.Description{
            .one_line = "sub3 with positional arguments",
        },
        .target = cli.CommandTarget{
            .action = cli.CommandAction{
                .positional_args = cli.PositionalArgs{
                    .required = try r.mkSlice(cli.PositionalArg, &.{
                        .{
                            .name = "ARG1",
                            .help = "arg1 help",
                            .value_ref = r.mkRef(&config.arg1),
                        },
                    }),
                    .optional = try r.mkSlice(cli.PositionalArg, &.{
                        .{
                            .name = "ARG2",
                            .help = "multiple arg2 help",
                            .value_ref = r.mkRef(&config.arg2),
                        },
                    }),
                },
                .exec = run_sub3,
            },
        },
    };
}

fn parseArgs() cli.AppRunner.Error!cli.ExecFn {
    var r = try cli.AppRunner.init(std.heap.page_allocator);

    const sub2 = cli.Command{
        .name = "sub2",
        .target = cli.CommandTarget{
            .action = cli.CommandAction{
                .exec = run_sub2,
            },
        },
    };

    const app = cli.App{
        .command = cli.Command{
            .name = "simple",
            .description = cli.Description{
                .one_line = "This a simple CLI app. Enjoy!",
            },
            .target = cli.CommandTarget{
                .subcommands = &.{
                    cli.Command{
                        .name = "sub1",
                        .description = cli.Description{
                            .one_line = "another awesome command",
                            .detailed =
                            \\this is my awesome multiline description.
                            \\This is already line 2.
                            \\And this is line 3.
                            ,
                        },
                        .options = &.{
                            .{
                                .long_name = "ip",
                                .help = "this is the IP address",
                                .short_alias = 'i',
                                .value_ref = r.mkRef(&config.ip),
                                .required = true,
                                .value_name = "IP",
                            },
                            .{
                                .long_name = "int",
                                .help = "this is an int",
                                .value_ref = r.mkRef(&config.int),
                            },
                            .{
                                .long_name = "bool",
                                .short_alias = 'b',
                                .help = "this is a bool",
                                .value_ref = r.mkRef(&config.bool),
                            },
                            .{
                                .long_name = "float",
                                .help = "this is a float",
                                .value_ref = r.mkRef(&config.float),
                            },
                        },
                        .target = cli.CommandTarget{
                            .subcommands = &.{ sub2, try sub3(&r) },
                        },
                    },
                },
            },
        },
        .version = "0.10.3",
        .author = "sam701 & contributors",
    };

    return r.getAction(&app);
}

pub fn main() anyerror!void {
    const action = try parseArgs();
    return action();
}

fn run_sub3() !void {
    const c = &config;
    std.log.debug("sub3: arg1: {}", .{c.arg1});
    for (c.arg2) |arg| {
        std.log.debug("sub3: arg2: {s}", .{arg});
    }
}

fn run_sub2() !void {
    const c = &config;
    std.log.debug("running sub2: ip={s}, bool={any}, float={any}", .{ c.ip, c.bool, c.float });
}
