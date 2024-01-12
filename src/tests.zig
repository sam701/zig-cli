const std = @import("std");
const Allocator = std.mem.Allocator;

const command = @import("./command.zig");
const ppack = @import("./parser.zig");
const mkRef = @import("./value_ref.zig").mkRef;
const Parser = ppack.Parser;
const ParseResult = ppack.ParseResult;

const expect = std.testing.expect;
const alloc = std.testing.allocator;

const StringSliceIterator = struct {
    items: []const []const u8,
    index: usize = 0,

    pub fn next(self: *StringSliceIterator) ?[]const u8 {
        defer self.index += 1;
        return if (self.index < self.items.len) self.items[self.index] else null;
    }
};

fn run(app: *const command.App, items: []const []const u8) !void {
    var parser = try Parser(StringSliceIterator).init(
        app,
        .{ .items = items },
        alloc,
    );
    _ = try parser.parse();
    parser.deinit();
}

fn dummy_action() !void {}

fn runOptionsPArgs(input: []const []const u8, options: []const *command.Option, pargs: ?[]const *command.PositionalArg) !void {
    try run(
        &.{
            .command = .{
                .name = "cmd",
                .description = .{ .one_line = "short help" },
                .options = options,
                .target = .{
                    .action = .{
                        .positional_args = if (pargs) |p| .{ .args = p } else null,
                        .exec = dummy_action,
                    },
                },
            },
        },
        input,
    );
}

fn runOptions(input: []const []const u8, options: []const *command.Option) !void {
    try runOptionsPArgs(input, options, null);
}

test "long option" {
    var aa: []const u8 = "test";
    var opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };

    try runOptions(&.{ "cmd", "--aa", "val" }, &.{&opt});
    try std.testing.expectEqualStrings("val", aa);

    try runOptions(&.{ "cmd", "--aa=bb" }, &.{&opt});
    try std.testing.expectEqualStrings("bb", aa);
}

test "short option" {
    var aa: []const u8 = undefined;
    var opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };

    try runOptions(&.{ "abc", "-a", "val" }, &.{&opt});
    try std.testing.expectEqualStrings("val", aa);

    try runOptions(&.{ "abc", "-a=bb" }, &.{&opt});
    try std.testing.expectEqualStrings("bb", aa);
}

test "concatenated aliases" {
    var aa: []const u8 = undefined;
    var bb: bool = false;
    var bbopt = command.Option{
        .long_name = "bb",
        .short_alias = 'b',
        .help = "option bb",
        .value_ref = mkRef(&bb),
    };
    var opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };

    try runOptions(&.{ "abc", "-ba", "val" }, &.{ &opt, &bbopt });
    try std.testing.expectEqualStrings("val", aa);
    try expect(bb);
}

test "int and float" {
    var aa: i32 = undefined;
    var bb: f64 = undefined;
    var aa_opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };
    var bb_opt = command.Option{
        .long_name = "bb",
        .help = "option bb",
        .value_ref = mkRef(&bb),
    };

    try runOptions(&.{ "abc", "--aa=34", "--bb", "15.25" }, &.{ &aa_opt, &bb_opt });
    try expect(34 == aa);
    try expect(15.25 == bb);
}

test "bools" {
    var aa: bool = true;
    var bb: bool = false;
    var cc: bool = false;
    var aa_opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };
    var bb_opt = command.Option{
        .long_name = "bb",
        .help = "option bb",
        .value_ref = mkRef(&bb),
    };
    var cc_opt = command.Option{
        .long_name = "cc",
        .short_alias = 'c',
        .help = "option cc",
        .value_ref = mkRef(&cc),
    };

    try runOptions(&.{ "abc", "--aa=faLSE", "-c", "--bb", "trUE" }, &.{ &aa_opt, &bb_opt, &cc_opt });
    try expect(!aa);
    try expect(bb);
    try expect(cc);
}

test "optional values" {
    var aa: ?i32 = null;
    var bb: ?f32 = 500;
    var cc: ?f32 = null;

    var aa_opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };
    var bb_opt = command.Option{
        .long_name = "bb",
        .help = "option bb",
        .value_ref = mkRef(&bb),
    };
    var cc_opt = command.Option{
        .long_name = "cc",
        .help = "option cc",
        .value_ref = mkRef(&cc),
    };

    try runOptions(&.{ "abc", "--aa=34", "--bb", "15.25" }, &.{ &aa_opt, &bb_opt, &cc_opt });
    try expect(34 == aa.?);
    try expect(15.25 == bb.?);
    try std.testing.expect(cc == null);
}

test "int list" {
    var aa: []u64 = undefined;
    var aa_opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };

    try runOptions(&.{ "abc", "--aa=100", "--aa", "200", "-a", "300", "-a=400" }, &.{&aa_opt});
    try expect(aa.len == 4);
    try expect(aa[0] == 100);
    try expect(aa[1] == 200);
    try expect(aa[2] == 300);
    try expect(aa[3] == 400);

    alloc.free(aa);
}

test "string list" {
    var aa: [][]const u8 = undefined;
    var aa_opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };

    try runOptions(&.{ "abc", "--aa=a1", "--aa", "a2", "-a", "a3", "-a=a4" }, &.{&aa_opt});
    try expect(aa.len == 4);
    try std.testing.expectEqualStrings("a1", aa[0]);
    try std.testing.expectEqualStrings("a2", aa[1]);
    try std.testing.expectEqualStrings("a3", aa[2]);
    try std.testing.expectEqualStrings("a4", aa[3]);

    alloc.free(aa);
}

test "mix positional arguments and options" {
    var arg1: u32 = 0;
    var args: []const []const u8 = undefined;
    var aav: []const u8 = undefined;
    var bbv: []const u8 = undefined;
    var aa = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = mkRef(&aav),
    };
    var bb = command.Option{
        .long_name = "bb",
        .help = "option bb",
        .value_ref = mkRef(&bbv),
    };
    var parg1 = command.PositionalArg{
        .name = "abc1",
        .help = "help",
        .value_ref = mkRef(&arg1),
    };
    var parg2 = command.PositionalArg{
        .name = "abc",
        .help = "help",
        .value_ref = mkRef(&args),
    };

    try runOptionsPArgs(&.{ "cmd", "--bb", "tt", "178", "-a", "val", "arg2", "--", "--arg3", "-arg4" }, &.{ &aa, &bb }, &.{ &parg1, &parg2 });
    defer std.testing.allocator.free(args);

    try std.testing.expectEqualStrings("val", aav);
    try std.testing.expectEqualStrings("tt", bbv);
    try std.testing.expect(arg1 == 178);
    try std.testing.expectEqual(@as(usize, 3), args.len);
    try std.testing.expectEqualStrings("arg2", args[0]);
    try std.testing.expectEqualStrings("--arg3", args[1]);
    try std.testing.expectEqualStrings("-arg4", args[2]);
}

test "parse enums" {
    const Aa = enum {
        cc,
        dd,
    };
    var aa: []Aa = undefined;
    var aa_opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };

    try runOptions(&.{ "abc", "--aa=cc", "--aa", "dd" }, &.{&aa_opt});
    try std.testing.expect(2 == aa.len);
    try std.testing.expect(aa[0] == Aa.cc);
    try std.testing.expect(aa[1] == Aa.dd);

    alloc.free(aa);
}
