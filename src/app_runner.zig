const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const value_ref = @import("value_ref.zig");
const ValueRef = value_ref.ValueRef;
const App = @import("command.zig").App;
const parser = @import("parser.zig");
const Parser = parser.Parser;
const Printer = @import("Printer.zig");
const command = @import("command.zig");

pub const AppRunner = struct {
    // This arena and its allocator is intended to be used only for the value references
    // that must be freed after the parsing is finished.
    // For everything else the original allocator, i.e. arena.child_allocator should be used.
    arena: ArenaAllocator,
    alloc: Allocator,

    const Self = @This();
    pub fn init(alloc: Allocator) !*Self {
        var arena = ArenaAllocator.init(alloc);
        var sptr = try arena.allocator().create(Self);

        sptr.arena = arena;
        sptr.alloc = sptr.arena.allocator();
        return sptr;
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    pub fn mkRef(self: *Self, dest: anytype) *ValueRef {
        return value_ref.allocRef(dest, self.alloc);
    }

    pub fn mkSlice(self: *Self, comptime T: type, content: []const T) ![]T {
        const dest = try self.alloc.alloc(T, content.len);
        std.mem.copyForwards(T, dest, content);
        return dest;
    }

    pub const ArgumentError = error.ArgumentError;
    const Error = Allocator.Error || error{ArgumentError};
    pub fn parse(self: *Self, app: *const App) Error!command.ExecFn {
        const iter = try std.process.argsWithAllocator(self.alloc);

        // Here we pass the child allocator because any values allocated on the client behalf may not be freed.
        var cr = try Parser(std.process.ArgIterator).init(app, iter, self.arena.child_allocator);
        defer cr.deinit();

        if (cr.parse()) |action| {
            self.deinit();
            return action;
        } else |err| {
            processError(err, cr.error_data orelse unreachable, app);
            return ArgumentError;
        }
    }

    pub fn run(self: *Self, app: *const App) !void {
        const iter = try std.process.argsWithAllocator(self.alloc);

        // Here we pass the child allocator because any values allocated on the client behalf may not be freed.
        var cr = try Parser(std.process.ArgIterator).init(app, iter, self.arena.child_allocator);
        defer cr.deinit();

        if (cr.parse()) |action| {
            self.deinit();
            return action();
        } else |err| {
            processError(err, cr.error_data orelse unreachable, app);
        }
    }
};

fn processError(err: parser.ParseError, err_data: parser.ErrorData, app: *const App) void {
    switch (err) {
        error.UnknownOption => printError(app, "unknown option '--{s}'", .{err_data.provided_string}),
        error.UnknownOptionAlias => printError(app, "unknown option alias '-{c}'", .{err_data.option_alias}),
        error.UnknownSubcommand => printError(app, "unknown subcommand '{s}'", .{err_data.provided_string}),
        error.MissingRequiredOption => printError(app, "missing required option '--{s}'", .{err_data.entity_name}),
        error.MissingRequiredPositionalArgument => printError(app, "missing required positional argument '{s}'", .{err_data.entity_name}),
        error.MissingSubcommand => printError(app, "command '{s}' requires subcommand", .{err_data.entity_name}),
        error.MissingOptionValue => printError(app, "option ('--{s}') requires value", .{err_data.entity_name}),
        error.UnexpectedPositionalArgument => printError(app, "unexpected positional argument '{s}'", .{err_data.provided_string}),
        error.CommandDoesNotHavePositionalArguments => printError(app, "command '{s}' does not have positional arguments", .{err_data.entity_name}),
        error.InvalidValue => {
            const iv = err_data.invalid_value;
            const et = if (iv.entity_type == .option) "option" else "positional argument";
            const px = if (iv.entity_type == .option) "--" else "";
            if (iv.envvar) |ev| {
                printError(app, "failed to parse option (--{s}) value '{s}' as {s} read from envvar {s}", .{ iv.entity_name, iv.provided_string, iv.value_type, ev });
            } else {
                printError(app, "failed to parse {s} ({s}{s}) provided value '{s}' as {s}", .{ et, px, iv.entity_name, iv.provided_string, iv.value_type });
            }
        },
        error.OutOfMemory => printError(app, "out of memory", .{}),
    }
}

fn printError(app: *const App, comptime fmt: []const u8, args: anytype) void {
    var p = Printer.init(std.io.getStdErr(), app.help_config.color_usage);

    p.printInColor(app.help_config.color_error, "ERROR");
    p.format(": ", .{});
    p.format(fmt, args);
    p.write(&.{'\n'});
    std.os.exit(1);
}
