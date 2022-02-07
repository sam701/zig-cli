const std = @import("std");
const cli = @import("cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() anyerror!void {
    const app = &cli.Command{
        .name = "abc",
        .usage = "this is a test command",
        .subcommands = &.{
          &cli.Command{
              .name = "sub1",
              .usage = "it's a try",
              .action = run_simple,
          }
        },
        .action = run_simple,
    };

    return cli.run(app, allocator);
}

fn run_simple(_: *const cli.CalledCommand) anyerror!void {}
