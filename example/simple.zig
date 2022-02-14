const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const ip_flag = &cli.Flag{
    .name = "ip",
    .usage = "this is the IP address",
    .value_type = .string,
};
const int_flag = &cli.Flag{
    .name = "int",
    .usage = "this is an int",
    .value_type = .int,
};
const bool_flag = &cli.Flag{
    .name = "bool",
    .usage = "this is a bool",
    .value_type = .bool,
};
const app = &cli.Command{
    .name = "abc",
    .usage = "this is a test command",
    .subcommands = &.{&cli.Command{
        .name = "sub1",
        .usage = "it's a try",
        .flags = &.{
            ip_flag,
            int_flag,
            bool_flag,
            &cli.Flag{
                .name = "float",
                .usage = "this is a float",
                .value_type = .float,
            },
        },
        .subcommands = &.{
            &cli.Command{
                .name = "sub2",
                .usage = "sub2 usage",
                .flags = &.{&cli.Flag{
                    .name = "name",
                    .usage = "name usage",
                    .value_type = .string,
                }},
                .action = run_sub2,
            },
        },
        .action = run_sub1,
    }},
    .action = run_main,
};

pub fn main() anyerror!void {
    return cli.run(app, allocator);
}

fn run_main(_: *const cli.Context) anyerror!void {
    std.log.debug("running main", .{});
}

fn run_sub1(_: *const cli.Context) anyerror!void {
    std.log.debug("running sub1: ip=", .{});
}

fn run_sub2(ctx: *const cli.Context) anyerror!void {
    var ip = ctx.string_flag_value(ip_flag).?;
    std.log.debug("running sub2: ip={s}, bool={}", .{ ip, ctx.is_flag_set(bool_flag) });
}
