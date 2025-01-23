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
    // For everything else the original allocator.
    arena: ArenaAllocator,
    orig_allocator: Allocator,

    const Self = @This();
    pub fn init(alloc: Allocator) !Self {
        return .{
            .arena = ArenaAllocator.init(alloc),
            .orig_allocator = alloc,
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    pub fn mkRef(self: *Self, dest: anytype) *ValueRef {
        return value_ref.allocRef(dest, self.arena.allocator());
    }

    /// mkSlice allocates a slice and copies the given content into it.
    /// The slice will be freed when the `parse` returns.
    fn mkSlice(self: *Self, comptime T: type, content: []const T) ![]T {
        const dest = try self.arena.allocator().alloc(T, content.len);
        std.mem.copyForwards(T, dest, content);
        return dest;
    }
    pub fn mkPositionalArgs(self: *Self, args: []const command.PositionalArg) ![]command.PositionalArg {
        return self.mkSlice(command.PositionalArg, args);
    }
    pub fn mkOptions(self: *Self, args: []const command.Option) ![]command.Option {
        return self.mkSlice(command.Option, args);
    }
    pub fn mkCommands(self: *Self, args: []const command.Command) ![]command.Command {
        return self.mkSlice(command.Command, args);
    }

    pub const ArgumentError = error.ArgumentError;
    pub const Error = Allocator.Error || error{ArgumentError};

    /// `getAction` returns the action function that should be called by the main app.
    pub fn getAction(self: *Self, app: *const App) Error!command.ExecFn {
        const iter = try std.process.argsWithAllocator(self.arena.allocator());

        // Here we pass the child allocator because any values allocated on the client behalf may not be freed.
        var cr = try Parser(std.process.ArgIterator).init(app, iter, self.orig_allocator);
        defer cr.deinit();

        if (cr.parse()) |action| {
            self.deinit();
            return action;
        } else |err| {
            processError(err, cr.error_data orelse unreachable, app);
            return ArgumentError;
        }
    }

    /// run calls `parse` and runs the action function returned.
    ///
    /// Consider using `getAction` instead of `run` if you want to free the app struct from the stack
    /// before executing the action function. See `examples/simple.zig`.
    pub fn run(self: *Self, app: *const App) !void {
        const action = try self.getAction(app);
        return action();
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
            if (iv.envvar) |ev| {
                printError(
                    app,
                    "failed to parse '{s}' (read from envvar {s}) as the value for option '--{s}' which is of type {s}",
                    .{ iv.provided_string, ev, iv.entity_name, iv.value_type },
                );
            } else {
                const et = if (iv.entity_type == .option) "option" else "positional argument";
                const px = if (iv.entity_type == .option) "--" else "";
                printError(
                    app,
                    "failed to parse '{s}' as the value for {s} '{s}{s}' which is of type {s}",
                    .{ iv.provided_string, et, px, iv.entity_name, iv.value_type },
                );
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
    std.posix.exit(1);
}
