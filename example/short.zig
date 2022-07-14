const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var host = cli.Option{
    .long_name = "host",
    .help = "host to listen on",
    .value = cli.OptionValue{ .string = "localhost" },
};
var port = cli.Option{
    .long_name = "port",
    .help = "port to bind to",
    .required = true,
    .value = cli.OptionValue{ .int = null },
};
var app = &cli.Command{
    .name = "run",
    .help = "run the server",
    .options = &.{ &host, &port },
    .action = run_server,
};

pub fn main() !void {
    return cli.run(app, allocator);
}

fn run_server(_: []const []const u8) !void {
    var h = host.value.string.?;
    var p = port.value.int.?;
    std.log.debug("server is listening on {s}:{}", .{ h, p });
}
