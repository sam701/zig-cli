const std = @import("std");
const Allocator = std.mem.Allocator;

const command = @import("./command.zig");
const ppack = @import("./parser.zig");
const Parser = ppack.Parser;
const ParseResult = ppack.ParseResult;
const iterators = @import("./iterators.zig");

const expect = std.testing.expect;

fn run(cmd: *command.Command, items: []const []const u8) !ParseResult {
    var it = iterators.StringSliceIterator{
        .items = items,
    };

    var parser = try Parser(iterators.StringSliceIterator).init(cmd, it, std.testing.allocator);
    var result = try parser.parse();
    parser.deinit();
    return result;
}

fn dummy_action(_: []const []const u8) !void {}

test "long option" {
    var opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value = command.OptionValue{ .string = null },
    };
    var cmd = command.Command{
        .name = "abc",
        .options = &.{&opt},
        .help = "help",
        .action = dummy_action,
    };

    _ = try run(&cmd, &.{ "cmd", "--aa", "val" });
    try expect(std.mem.eql(u8, opt.value.string.?, "val"));

    _ = try run(&cmd, &.{ "cmd", "--aa=bb" });
    try expect(std.mem.eql(u8, opt.value.string.?, "bb"));
}

test "short option" {
    var opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value = command.OptionValue{ .string = null },
    };
    var cmd = command.Command{
        .name = "abc",
        .options = &.{&opt},
        .help = "help",
        .action = dummy_action,
    };

    _ = try run(&cmd, &.{ "abc", "-a", "val" });
    try expect(std.mem.eql(u8, opt.value.string.?, "val"));

    _ = try run(&cmd, &.{ "abc", "-a=bb" });
    try expect(std.mem.eql(u8, opt.value.string.?, "bb"));
}

test "concatenated aliases" {
    var bb = command.Option{
        .long_name = "bb",
        .short_alias = 'b',
        .help = "option bb",
        .value = command.OptionValue{ .bool = false },
    };
    var opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value = command.OptionValue{ .string = null },
    };
    var cmd = command.Command{
        .name = "abc",
        .options = &.{ &bb, &opt },
        .help = "help",
        .action = dummy_action,
    };

    _ = try run(&cmd, &.{ "abc", "-ba", "val" });
    try expect(std.mem.eql(u8, opt.value.string.?, "val"));
    try expect(bb.value.bool);
}

test "int and float" {
    var aa = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value = command.OptionValue{ .int = null },
    };
    var bb = command.Option{
        .long_name = "bb",
        .help = "option bb",
        .value = command.OptionValue{ .float = null },
    };
    var cmd = command.Command{
        .name = "abc",
        .options = &.{ &aa, &bb },
        .help = "help",
        .action = dummy_action,
    };

    _ = try run(&cmd, &.{ "abc", "--aa=34", "--bb", "15.25" });
    try expect(aa.value.int.? == 34);
    try expect(bb.value.float.? == 15.25);
}
