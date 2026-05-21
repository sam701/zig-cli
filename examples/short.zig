const std = @import("std");
const cli = @import("cli");

var config = struct {
    host: []const u8 = "localhost",
    port: u16 = undefined,
}{};

pub fn main(init: std.process.Init) !void {
    var r = cli.AppRunner.init(&init);
    defer r.deinit();

    const app = cli.App{
        .command = cli.Command{
            .name = "server",
            .options = try r.allocOptions(&.{
                .{
                    .long_name = "host",
                    .help = "host to listen on",
                    .value_ref = r.mkRef(&config.host),
                },
                .{
                    .long_name = "port",
                    .help = "port to bind to",
                    .required = true,
                    .value_ref = r.mkRef(&config.port),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = run },
            },
        },
    };
    return r.run(&app);
}

fn run() !void {
    std.log.info("listening on {s}:{d}", .{ config.host, config.port });
}
