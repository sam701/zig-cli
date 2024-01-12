const std = @import("std");
const cli = @import("zig-cli");

// Create a GeneralPurposeAllocator for heap allocations.
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
// Obtain the allocator from the GeneralPurposeAllocator.
const allocator = gpa.allocator();

// Define a configuration structure with default values.
var config = struct {
    host: []const u8 = "localhost",
    port: u16 = undefined,
}{};

// Define an Option for the "host" command-line argument.
var host = cli.Option{
    .long_name = "host",
    .help = "host to listen on",
    .value_ref = cli.mkRef(&config.host),
};

// Define an Option for the "port" command-line argument.
var port = cli.Option{
    .long_name = "port",
    .help = "port to bind to",
    .required = true,
    .value_ref = cli.mkRef(&config.port),
};

// Create an App with a command named "short" that takes host and port options.
var app = &cli.App{
    .command = cli.Command{
        .name = "short",
        .options = &.{ &host, &port },
        .target = cli.CommandTarget{
            .action = cli.CommandAction{ .exec = run_server },
        },
    },
};

// Main function where the CLI is run with the provided app and allocator.
pub fn main() !void {
    return cli.run(app, allocator);
}

// Action function to execute when the "short" command is invoked.
fn run_server() !void {
    // Log a debug message indicating the server is listening on the specified host and port.
    std.log.debug("server is listening on {s}:{d}", .{ config.host, config.port });
}
