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
    sub3_opt: ?u64 = null,
}{};

fn sub3(r: *cli.AppRunner) !cli.Command {
    return cli.Command{
        .name = "sub3",
        .description = cli.Description{
            .one_line = "sub3 with positional arguments",
        },
        .options = try r.allocOptions(&.{
            cli.Option{
                .long_name = "sub3-opt",
                .help = "an integer option in a subcommand",
                .value_ref = r.mkRef(&config.sub3_opt),
                .value_name = "INT",
            },
        }),
        .target = cli.CommandTarget{
            .action = cli.CommandAction{
                .positional_args = cli.PositionalArgs{
                    .required = try r.allocPositionalArgs(&.{
                        .{
                            .name = "ARG1",
                            .help = "arg1 help",
                            .value_ref = r.mkRef(&config.arg1),
                        },
                    }),
                    .optional = try r.allocPositionalArgs(&.{
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
    // This allocator will be used to allocate config.ip and config.arg2.
    var r = try cli.AppRunner.init(allocator);

    const sub2 = cli.Command{
        .name = "sub2",
        .target = cli.CommandTarget{
            .action = cli.CommandAction{
                .exec = run_sub2,
            },
        },
    };

    // Since we call r.getAction in this fuction, all r.alloc* invocation are unnecessary.
    // We can directly pass slices of commands, options, and posititional arguments,
    // like `.options = &.{....}`

    const app = cli.App{
        .command = cli.Command{
            .name = "simple",
            .description = cli.Description{
                .one_line = "This a simple CLI app. Enjoy!",
            },
            .target = cli.CommandTarget{
                .subcommands = try r.allocCommands(&.{
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
                        .options = try r.allocOptions(&.{
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
                                .help = "this is an int\nwith the second line",
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
                        }),
                        .target = cli.CommandTarget{
                            .subcommands = try r.allocCommands(&.{ sub2, try sub3(&r) }),
                        },
                    },
                }),
            },
        },
        .version = "0.10.3",
        .author = "sam701 & contributors",
    };

    return r.getAction(&app);
}

pub fn main() anyerror!void {
    const action = try parseArgs();
    const r = action();
    freeConfig();
    return r;
}

// Usually, you just use an arena allocator to free all allocated resources in a batch.
// This only illustrates the fact that the config data are allocated with the allocator
// you pass to cli.AppRunner.init(allocator).
fn freeConfig() void {
    allocator.free(config.ip);
    if (config.arg2.len > 0) {
        for (config.arg2) |item| {
            allocator.free(item);
        }
        allocator.free(config.arg2);
    }
    if (gpa.deinit() == .leak) {
        @panic("config leaked");
    }
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
