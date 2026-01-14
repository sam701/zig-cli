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
const help = @import("./help.zig");

pub const AppRunner = struct {
    // Arena allocator for temporary data during parsing (ValueRefs, argument slices, etc.)
    // that is freed immediately after parsing completes.
    // The original allocator is used for data that outlives the parsing phase.
    arena: ArenaAllocator,
    orig_allocator: Allocator,
    io: std.Io,
    environ: *const std.process.Environ.Map,
    args: *const std.process.Args,

    const Self = @This();
    pub fn init(orig_init: *const std.process.Init) Self {
        return .{
            .arena = ArenaAllocator.init(orig_init.gpa),
            .orig_allocator = orig_init.gpa,
            .io = orig_init.io,
            .environ = orig_init.environ_map,
            .args = &orig_init.minimal.args,
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
    fn allocSlice(self: *Self, comptime T: type, content: []const T) ![]T {
        const dest = try self.arena.allocator().alloc(T, content.len);
        std.mem.copyForwards(T, dest, content);
        return dest;
    }
    pub fn allocPositionalArgs(self: *Self, args: []const command.PositionalArg) ![]command.PositionalArg {
        return self.allocSlice(command.PositionalArg, args);
    }
    pub fn allocOptions(self: *Self, args: []const command.Option) ![]command.Option {
        return self.allocSlice(command.Option, args);
    }
    pub fn allocCommands(self: *Self, args: []const command.Command) ![]command.Command {
        return self.allocSlice(command.Command, args);
    }

    pub const Error = Allocator.Error || error{WriteFailed};

    /// `getAction` returns the action function that should be called by the main app.
    pub fn getAction(self: *Self, app: *const App) Error!command.ExecFn {
        const iter = try self.args.iterateAllocator(self.arena.allocator());

        // Here we pass the child allocator because any values allocated on the client behalf may not be freed.
        var cr = try Parser(std.process.Args.Iterator).init(app, iter, self.io, self.orig_allocator, self.environ);
        defer cr.deinit();

        if (cr.parse()) |action| {
            self.deinit();
            return action;
        } else |err| {
            var buffer: [4096]u8 = undefined;
            var w = std.Io.File.stderr().writer(self.io, &buffer);
            var printer = Printer.init(&w);
            processError(&printer, err, cr.error_data orelse unreachable, app);
            if (app.help_config.print_help_on_error) {
                printer.printNewLine();
                try help.print_command_help(&printer, app, try cr.command_path.toOwnedSlice(self.orig_allocator), cr.global_options);
            }
            std.process.exit(1);
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

fn processError(p: *Printer, err: parser.ParseError, err_data: parser.ErrorData, app: *const App) void {
    switch (err) {
        error.UnknownOption => printError(p, app, "unknown option '--{s}'", .{err_data.provided_string}),
        error.UnknownOptionAlias => printError(p, app, "unknown option alias '-{c}'", .{err_data.option_alias}),
        error.UnknownSubcommand => printError(p, app, "unknown subcommand '{s}'", .{err_data.provided_string}),
        error.MissingRequiredOption => printError(p, app, "missing required option '--{s}'", .{err_data.entity_name}),
        error.MissingRequiredPositionalArgument => printError(p, app, "missing required positional argument '{s}'", .{err_data.entity_name}),
        error.MissingSubcommand => printError(p, app, "command '{s}' requires subcommand", .{err_data.entity_name}),
        error.MissingOptionValue => printError(p, app, "option ('--{s}') requires value", .{err_data.entity_name}),
        error.UnexpectedPositionalArgument => printError(p, app, "unexpected positional argument '{s}'", .{err_data.provided_string}),
        error.CommandDoesNotHavePositionalArguments => printError(p, app, "command '{s}' does not have positional arguments", .{err_data.entity_name}),
        error.InvalidValue => {
            const iv = err_data.invalid_value;
            if (iv.envvar) |ev| {
                printError(
                    p,
                    app,
                    "failed to parse '{s}' (read from envvar {s}) as the value for option '--{s}' which is of type {s}",
                    .{ iv.provided_string, ev, iv.entity_name, iv.value_type },
                );
            } else {
                const et = if (iv.entity_type == .option) "option" else "positional argument";
                const px = if (iv.entity_type == .option) "--" else "";
                printError(
                    p,
                    app,
                    "failed to parse '{s}' as the value for {s} '{s}{s}' which is of type {s}",
                    .{ iv.provided_string, et, px, iv.entity_name, iv.value_type },
                );
            }
        },
        error.OutOfMemory => printError(p, app, "out of memory", .{}),
    }
}

pub fn printError(p: *Printer, app: *const App, comptime fmt: []const u8, args: anytype) void {
    p.printInColor(app.help_config.color_error, "ERROR");
    p.format(": ", .{});
    p.format(fmt, args);
    p.write(&.{'\n'});
}
