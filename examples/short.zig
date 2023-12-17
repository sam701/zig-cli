const std = @import("std");
const cli = @import("zig-cli");

var config = struct {
    host: []const u8 = "localhost",
    port: u16 = undefined,
}{};

pub fn main() !void {
    var r = try cli.AppRunner.init(std.heap.page_allocator);

    const app = cli.App{
        .command = cli.Command{
            .name = "short",
            .options = &.{
                &cli.Option{
                    .long_name = "port",
                    .help = "port to bind to",
                    .required = true,
                    .value_ref = r.mkRef(&config.port),
                },
                &cli.Option{
                    .long_name = "host",
                    .help = "host to listen on",
                    .value_ref = r.mkRef(&config.host),
                },
            },
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = run_server },
            },
        },
    };
    return r.run(&app);
}

fn run_server() !void {
    std.log.debug("server is listening on {s}:{}", .{ config.host, config.port });
}
