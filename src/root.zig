//! ## Example
//!
//! ```
//! const std = @import("std");
//! const cli = @import("cli");
//!
//! // Define a configuration structure with default values.
//! var config = struct {
//!     host: []const u8 = "localhost",
//!     port: u16 = undefined,
//! }{};
//!
//! pub fn main(init: std.process.Init) !void {
//!     var r = cli.AppRunner.init(&init);
//!
//!     // Create an App with a command named "short" that takes host and port options.
//!     const app = cli.App{
//!         .command = cli.Command{
//!             .name = "short",
//!             .options = try r.allocOptions(&.{
//!                 // Define an Option for the "host" command-line argument.
//!                 .{
//!                     .long_name = "host",
//!                     .help = "host to listen on",
//!                     .value_ref = r.mkRef(&config.host),
//!                 },
//!
//!                 // Define an Option for the "port" command-line argument.
//!                 .{
//!                     .long_name = "port",
//!                     .help = "port to bind to",
//!                     .required = true,
//!                     .value_ref = r.mkRef(&config.port),
//!                 },
//!             }),
//!             .target = cli.CommandTarget{
//!                 .action = cli.CommandAction{ .exec = run_server },
//!             },
//!         },
//!     };
//!     return r.run(&app);
//! }
//!
//! // Action function to execute when the "short" command is invoked.
//! fn run_server() !void {
//!     // Log a debug message indicating the server is listening on the specified host and port.
//!     std.log.debug("server is listening on {s}:{d}", .{ config.host, config.port });
//! }
//! ```
const cmd = @import("./command.zig");

pub const ValueRef = cmd.ValueRef;
pub const App = cmd.App;
pub const ColorUsage = cmd.ColorUsage;
pub const HelpConfig = cmd.HelpConfig;
pub const Command = cmd.Command;
pub const Description = cmd.Description;
pub const CommandTarget = cmd.CommandTarget;
pub const CommandAction = cmd.CommandAction;
pub const ExecFn = cmd.ExecFn;
pub const Option = cmd.Option;
pub const PositionalArgs = cmd.PositionalArgs;
pub const PositionalArg = cmd.PositionalArg;

const app_runner = @import("./app_runner.zig");
pub const AppRunner = app_runner.AppRunner;
pub const printError = app_runner.printError;

test {
    _ = @import("tests.zig");
}
