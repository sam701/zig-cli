const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var config = struct {
    host: []const u8 = "localhost",
    port: u16 = 3000,
    base_value: f64 = undefined,
    expose_metrics: bool = false,
}{};

var host_option = cli.Option{
    .long_name = "host",
    .help = "host to listen on",
    .short_alias = 'h',
    .value = cli.OptionValue{ .string = null },
    .required = true,
    .value_name = "IP",
};
var port_option = cli.Option{
    .long_name = "port",
    .help = "post to bind to",
    .value = cli.OptionValue{ .int = null },
};
var expose_metrics_option = cli.Option{
    .long_name = "expose-metrics",
    .short_alias = 'm',
    .help = "if the metrics should be exposed",
    .value = cli.OptionValue{ .bool = false },
};
var base_value_option = cli.Option{
    .long_name = "base-value",
    .help = "base value",
    .value = cli.OptionValue{ .float = 0.34 },
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
            &host_option,
            &port_option,
            &expose_metrics_option,
            &base_value_option,
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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    const al = arena.allocator();

    var ctx = cli.Context.init(al);
    host_option.value_ref = try ctx.valueRef(&config.host);
    port_option.value_ref = try ctx.valueRef(&config.port);
    expose_metrics_option.value_ref = try ctx.valueRef(&config.expose_metrics);
    base_value_option.value_ref = try ctx.valueRef(&config.base_value);

    return cli.run(app, allocator);
}

fn run_sub2(args: []const []const u8) anyerror!void {
    var ip = host_option.value.string.?;
    std.log.debug("running sub2: ip={s}, bool={any}, float={any} arg_count={any}", .{ ip, expose_metrics_option.value.bool, base_value_option.value.float, args.len });
}
