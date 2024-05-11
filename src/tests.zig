const std = @import("std");
const Allocator = std.mem.Allocator;

const command = @import("./command.zig");
const ppack = @import("./parser.zig");
const Parser = ppack.Parser;
const ParseResult = ppack.ParseResult;
const AppRunner = @import("app_runner.zig").AppRunner;

const expect = std.testing.expect;
const alloc = std.testing.allocator;
const expectError = std.testing.expectError;

const StringSliceIterator = struct {
    items: []const []const u8,
    index: usize = 0,

    pub fn next(self: *StringSliceIterator) ?[]const u8 {
        defer self.index += 1;
        return if (self.index < self.items.len) self.items[self.index] else null;
    }
};

fn runner() AppRunner {
    return AppRunner.init(alloc) catch unreachable;
}

fn run(app: *const command.App, items: []const []const u8) !void {
    var parser = try Parser(StringSliceIterator).init(
        app,
        StringSliceIterator{ .items = items },
        alloc,
    );
    defer parser.deinit();
    _ = try parser.parse();
}

fn dummy_action() !void {}

fn runOptionsPArgs(input: []const []const u8, options: []const command.Option, pargs: ?[]const command.PositionalArg) !void {
    const pa = if (pargs) |p| command.PositionalArgs{ .required = p } else null;
    const app = command.App{
        .command = .{
            .name = "cmd",
            .description = command.Description{ .one_line = "short help" },
            .options = options,
            .target = command.CommandTarget{
                .action = command.CommandAction{
                    .positional_args = pa,
                    .exec = dummy_action,
                },
            },
        },
    };
    try run(&app, input);
}

fn runOptions(input: []const []const u8, options: []const command.Option) !void {
    try runOptionsPArgs(input, options, null);
}

test "long option" {
    var r = runner();
    defer r.deinit();
    var aa: []const u8 = "test";
    const opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };

    try runOptions(&.{ "cmd", "--aa", "val" }, &.{opt});
    try std.testing.expectEqualStrings("val", aa);

    try runOptions(&.{ "cmd", "--aa=bb" }, &.{opt});
    try std.testing.expectEqualStrings("bb", aa);
}

test "short option" {
    var r = runner();
    defer r.deinit();
    var aa: []const u8 = undefined;
    const opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };

    try runOptions(&.{ "abc", "-a", "val" }, &.{opt});
    try std.testing.expectEqualStrings("val", aa);

    try runOptions(&.{ "abc", "-a=bb" }, &.{opt});
    try std.testing.expectEqualStrings("bb", aa);
}

test "concatenated aliases" {
    var r = runner();
    defer r.deinit();
    var aa: []const u8 = undefined;
    var bb: bool = false;
    const bbopt = command.Option{
        .long_name = "bb",
        .short_alias = 'b',
        .help = "option bb",
        .value_ref = r.mkRef(&bb),
    };
    const opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };

    try runOptions(&.{ "abc", "-ba", "val" }, &.{ opt, bbopt });
    try std.testing.expectEqualStrings("val", aa);
    try expect(bb);
}

test "int and float" {
    var r = runner();
    defer r.deinit();
    var aa: i32 = undefined;
    var bb: f64 = undefined;
    const aa_opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };
    const bb_opt = command.Option{
        .long_name = "bb",
        .help = "option bb",
        .value_ref = r.mkRef(&bb),
    };

    try runOptions(&.{ "abc", "--aa=34", "--bb", "15.25" }, &.{ aa_opt, bb_opt });
    try expect(34 == aa);
    try expect(15.25 == bb);
}

test "bools" {
    var r = runner();
    defer r.deinit();
    var aa: bool = true;
    var bb: bool = false;
    var cc: bool = false;
    const aa_opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };
    const bb_opt = command.Option{
        .long_name = "bb",
        .help = "option bb",
        .value_ref = r.mkRef(&bb),
    };
    const cc_opt = command.Option{
        .long_name = "cc",
        .short_alias = 'c',
        .help = "option cc",
        .value_ref = r.mkRef(&cc),
    };

    try runOptions(&.{ "abc", "--aa=faLSE", "-c", "--bb", "trUE" }, &.{ aa_opt, bb_opt, cc_opt });
    try expect(!aa);
    try expect(bb);
    try expect(cc);
}

test "optional values" {
    var r = runner();
    defer r.deinit();
    var aa: ?i32 = null;
    var bb: ?f32 = 500;
    var cc: ?f32 = null;

    const aa_opt = command.Option{
        .long_name = "aa",
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };
    const bb_opt = command.Option{
        .long_name = "bb",
        .help = "option bb",
        .value_ref = r.mkRef(&bb),
    };
    const cc_opt = command.Option{
        .long_name = "cc",
        .help = "option cc",
        .value_ref = r.mkRef(&cc),
    };

    try runOptions(&.{ "abc", "--aa=34", "--bb", "15.25" }, &.{ aa_opt, bb_opt, cc_opt });
    try expect(34 == aa.?);
    try expect(15.25 == bb.?);
    try std.testing.expect(cc == null);
}

test "int list" {
    var r = runner();
    defer r.deinit();
    var aa: []u64 = undefined;
    const aa_opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };

    try runOptions(&.{ "abc", "--aa=100", "--aa", "200", "-a", "300", "-a=400" }, &.{aa_opt});
    try expect(aa.len == 4);
    try expect(aa[0] == 100);
    try expect(aa[1] == 200);
    try expect(aa[2] == 300);
    try expect(aa[3] == 400);

    alloc.free(aa);
}

test "string list" {
    var r = runner();
    defer r.deinit();
    var aa: [][]const u8 = undefined;
    const aa_opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };

    try runOptions(&.{ "abc", "--aa=a1", "--aa", "a2", "-a", "a3", "-a=a4" }, &.{aa_opt});
    try expect(aa.len == 4);
    try std.testing.expectEqualStrings("a1", aa[0]);
    try std.testing.expectEqualStrings("a2", aa[1]);
    try std.testing.expectEqualStrings("a3", aa[2]);
    try std.testing.expectEqualStrings("a4", aa[3]);

    alloc.free(aa);
}

test "mix positional arguments and options" {
    var r = runner();
    defer r.deinit();
    var arg1: u32 = 0;
    var args: []const []const u8 = undefined;
    var aav: []const u8 = undefined;
    var bbv: []const u8 = undefined;
    const aa = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = r.mkRef(&aav),
    };
    const bb = command.Option{
        .long_name = "bb",
        .help = "option bb",
        .value_ref = r.mkRef(&bbv),
    };
    const parg1 = command.PositionalArg{
        .name = "abc1",
        .help = "help",
        .value_ref = r.mkRef(&arg1),
    };
    const parg2 = command.PositionalArg{
        .name = "abc",
        .help = "help",
        .value_ref = r.mkRef(&args),
    };

    try runOptionsPArgs(&.{ "cmd", "--bb", "tt", "178", "-a", "val", "arg2", "--", "--arg3", "-arg4" }, &.{ aa, bb }, &.{ parg1, parg2 });
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
    var r = runner();
    defer r.deinit();
    const Aa = enum {
        cc,
        dd,
    };
    var aa: []Aa = undefined;
    const aa_opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };

    try runOptions(&.{ "abc", "--aa=cc", "--aa", "dd" }, &.{aa_opt});
    try std.testing.expect(2 == aa.len);
    try std.testing.expect(aa[0] == Aa.cc);
    try std.testing.expect(aa[1] == Aa.dd);

    alloc.free(aa);
}

test "unknown option" {
    var r = runner();
    defer r.deinit();
    var aa: []const u8 = undefined;
    const opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };

    try expectError(error.UnknownOption, runOptions(&.{ "abc", "--bad", "val" }, &.{opt}));

    try expectError(error.UnknownOptionAlias, runOptions(&.{ "abc", "-b", "val" }, &.{opt}));
}

test "unknown subcommand" {
    var r = runner();
    defer r.deinit();

    const app = command.App{
        .command = command.Command{
            .name = "abc",
            .target = command.CommandTarget{
                .subcommands = &.{},
            },
        },
    };

    try expectError(error.UnknownSubcommand, run(&app, &.{ "abc", "bad" }));
}

test "missing subcommand" {
    var r = runner();
    defer r.deinit();

    const app = command.App{
        .command = command.Command{
            .name = "abc",
            .target = command.CommandTarget{
                .subcommands = &.{},
            },
        },
    };

    try expectError(error.MissingSubcommand, run(&app, &.{"abc"}));
    try expectError(error.CommandDoesNotHavePositionalArguments, run(&app, &.{ "abc", "--", "3" }));
}

test "missing required option" {
    var r = runner();
    defer r.deinit();
    var aa: []const u8 = undefined;
    const opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .required = true,
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };

    try expectError(error.MissingRequiredOption, runOptions(&.{"abc"}, &.{opt}));
    try expectError(error.MissingOptionValue, runOptions(&.{ "abc", "--aa" }, &.{opt}));
}

test "missing positional argument" {
    var r = runner();
    defer r.deinit();

    var x: usize = 0;

    const app = command.App{
        .command = command.Command{
            .name = "abc",
            .target = command.CommandTarget{
                .action = command.CommandAction{
                    .positional_args = command.PositionalArgs{
                        .required = &.{
                            command.PositionalArg{
                                .name = "PA1",
                                .value_ref = r.mkRef(&x),
                            },
                        },
                    },
                    .exec = dummy_action,
                },
            },
        },
    };

    try expectError(error.MissingRequiredPositionalArgument, run(&app, &.{"abc"}));
    try expectError(error.UnexpectedPositionalArgument, run(&app, &.{ "abc", "3", "4" }));
}

test "command without positional arguments" {
    var r = runner();
    defer r.deinit();

    const app = command.App{
        .command = command.Command{
            .name = "abc",
            .target = command.CommandTarget{
                .action = command.CommandAction{
                    .exec = dummy_action,
                },
            },
        },
    };

    try expectError(error.CommandDoesNotHavePositionalArguments, run(&app, &.{ "abc", "3", "abc" }));
}

test "invalid value" {
    var r = runner();
    defer r.deinit();
    var aa: usize = undefined;
    const opt = command.Option{
        .long_name = "aa",
        .short_alias = 'a',
        .required = true,
        .help = "option aa",
        .value_ref = r.mkRef(&aa),
    };

    try expectError(error.InvalidValue, runOptions(&.{ "abc", "--aa", "bad" }, &.{opt}));
}
