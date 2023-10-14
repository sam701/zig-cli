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

        if (self.index < self.items.len) {
            return self.items[self.index];
        } else {
            return null;
        }
    }
};

fn run(app: *command.App, items: []const []const u8) !ParseResult {
    var it = StringSliceIterator{
        .items = items,
    };

    var parser = try Parser(StringSliceIterator).init(app, it, alloc);
    var result = try parser.parse();
    parser.deinit();
    return result;
}

fn dummy_action(_: []const []const u8) !void {}

test "long option" {
    var aa: []const u8 = "test";
    var opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value_ref = mkRef(&aa),
    };
    var cmd = command.App{
        .name = "abc",
        .options = &.{&opt},
        .action = dummy_action,
    };

    _ = try run(&cmd, &.{ "cmd", "--aa", "val" });
    try std.testing.expectEqualStrings("val", aa);

    _ = try run(&cmd, &.{ "cmd", "--aa=bb" });
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
    var app = command.App{
        .name = "abc",
        .options = &.{&opt},
        .action = dummy_action,
    };

    _ = try run(&app, &.{ "abc", "-a", "val" });
    try std.testing.expectEqualStrings("val", aa);

    _ = try run(&app, &.{ "abc", "-a=bb" });
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
    var app = command.App{
        .name = "abc",
        .options = &.{ &bbopt, &opt },
        .action = dummy_action,
    };

    _ = try run(&app, &.{ "abc", "-ba", "val" });
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
    var app = command.App{
        .name = "abc",
        .options = &.{ &aa_opt, &bb_opt },
        .action = dummy_action,
    };

    _ = try run(&app, &.{ "abc", "--aa=34", "--bb", "15.25" });
    try expect(34 == aa);
    try expect(15.25 == bb);
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
    var app = command.App{
        .name = "abc",
        .options = &.{ &aa_opt, &bb_opt, &cc_opt },
        .action = dummy_action,
    };

    _ = try run(&app, &.{ "abc", "--aa=34", "--bb", "15.25" });
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
    var app = command.App{
        .name = "abc",
        .options = &.{&aa_opt},
        .action = dummy_action,
    };

    _ = try run(&app, &.{ "abc", "--aa=100", "--aa", "200", "-a", "300", "-a=400" });
    try expect(aa.len == 4);
    try expect(aa[0] == 100);
    try expect(aa[1] == 200);
    try expect(aa[2] == 300);
    try expect(aa[3] == 400);

    // FIXME: it tries to deallocated u64 while the memory was allocated using u8 alignment
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
    var app = command.App{
        .name = "abc",
        .options = &.{&aa_opt},
        .action = dummy_action,
    };

    _ = try run(&app, &.{ "abc", "--aa=a1", "--aa", "a2", "-a", "a3", "-a=a4" });
    try expect(aa.len == 4);
    try std.testing.expectEqualStrings("a1", aa[0]);
    try std.testing.expectEqualStrings("a2", aa[1]);
    try std.testing.expectEqualStrings("a3", aa[2]);
    try std.testing.expectEqualStrings("a4", aa[3]);

    alloc.free(aa);
}

test "mix positional arguments and options" {
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
    var app = command.App{
        .name = "abc",
        .options = &.{ &aa, &bb },
        .action = dummy_action,
    };

    var result = try run(&app, &.{ "cmd", "--bb", "tt", "arg1", "-a", "val", "arg2", "--", "--arg3", "-arg4" });
    defer std.testing.allocator.free(result.args);
    try std.testing.expectEqualStrings("val", aav);
    try std.testing.expectEqualStrings("tt", bbv);
    try expect(result.args.len == 4);
    try std.testing.expectEqualStrings("arg1", result.args[0]);
    try std.testing.expectEqualStrings("arg2", result.args[1]);
    try std.testing.expectEqualStrings("--arg3", result.args[2]);
    try std.testing.expectEqualStrings("-arg4", result.args[3]);
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
    var app = command.App{
        .name = "abc",
        .options = &.{&aa_opt},
        .action = dummy_action,
    };

    _ = try run(&app, &.{ "abc", "--aa=cc", "--aa", "dd" });
    try std.testing.expect(2 == aa.len);
    try std.testing.expect(aa[0] == Aa.cc);
    try std.testing.expect(aa[1] == Aa.dd);

    alloc.free(aa);
}
