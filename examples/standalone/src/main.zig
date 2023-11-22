const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var config = struct {
    host: []const u8 = "localhost",
    port: u16 = undefined,
}{};

var host = cli.Option{
    .long_name = "host",
    .help = "host to listen on",
    .value_ref = cli.mkRef(&config.host),
};
var port = cli.Option{
    .long_name = "port",
    .help = "port to bind to",
    .required = true,
    .value_ref = cli.mkRef(&config.port),
};
var app = &cli.App{
    .command = cli.Command{
        .name = "short",
        .options = &.{ &host, &port },
        .target = cli.CommandTarget{
            .action = cli.CommandAction{ .exec = run_server },
        },
    },
};

pub fn main() !void {
    return cli.run(app, allocator);
}

fn run_server() !void {
    std.log.debug("server is listening on {s}:{}", .{ config.host, config.port });
}
