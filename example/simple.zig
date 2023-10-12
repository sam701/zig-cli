const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var config = struct {
    host: []const u8 = "localhost",
    port: u16 = 3000,
    base_value: f64 = undefined,
    expose_metrics: bool = false,
    testar: []i32 = undefined,
}{};

var host_option = cli.Option{
    .long_name = "host",
    .help = "host to listen on",
    .short_alias = 'h',
    .value = cli.OptionValue{ .string = null },
    .value_ref = cli.valueRef(&config.host),
    .required = true,
    .value_name = "IP",
};
var port_option = cli.Option{
    .long_name = "port",
    .help = "post to bind to",
    .value = cli.OptionValue{ .int = null },
    .value_ref = cli.valueRef(&config.port),
};
var ar_option = cli.Option{
    .long_name = "array",
    .help = "slice test",
    .value = cli.OptionValue{ .int = null },
    .value_ref = cli.valueRef(&config.testar),
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
    try port_option.value_ref.?.put("356", allocator);
    std.log.debug("port value = {}", .{config.port});

    try host_option.value_ref.?.put("awesome.com", allocator);
    std.log.debug("host value = {s}", .{config.host});

    try ar_option.value_ref.?.put("45", allocator);
    try ar_option.value_ref.?.put("94", allocator);
    try ar_option.value_ref.?.put("23456789", allocator);
    try ar_option.value_ref.?.finalize(allocator);
    std.log.debug("testar value = {any}", .{config.testar});
    return cli.run(app, allocator);
}

fn run_sub2(args: []const []const u8) anyerror!void {
    var ip = host_option.value.string.?;
    std.log.debug("running sub2: ip={s}, bool={any}, float={any} arg_count={any}", .{ ip, expose_metrics_option.value.bool, base_value_option.value.float, args.len });
}
