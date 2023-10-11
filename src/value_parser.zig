const std = @import("std");

// const Parser = *const fn (dest: *anyopaque, value: []const u8) anyerror!void;
pub fn ValueParser(comptime T: type) type {
    // TODO: the parse function might need an allocator, e.g. to copy a string or allocate the destination type if it is a pointer.
    return *const fn (dest: *T, value: []const u8) anyerror!void;
}

pub fn get(comptime T: type) ValueParser(T) {
    return switch (@typeInfo(T)) {
        .Int => intParser(T),
        .Float => floatParser(T),
        .Bool => boolParser(T),
        .Pointer => |pinfo| {
            if (pinfo.size == .Slice and pinfo.child == u8) {
                stringParser(T);
            }
        },
        else => @compileError("unsupported value type"),
    };
}

fn intParser(comptime T: type) ValueParser(T) {
    return struct {
        fn parser(dest: *T, value: []const u8) anyerror!void {
            dest.* = try std.fmt.parseInt(T, value, 10);
        }
    }.parser;
}

fn floatParser(comptime T: type) ValueParser(T) {
    return struct {
        fn parser(dest: *T, value: []const u8) anyerror!void {
            dest.* = try std.fmt.parseFloat(T, value);
        }
    }.parser;
}

fn boolParser(comptime T: type) ValueParser(T) {
    return struct {
        fn parser(dest: *T, value: []const u8) anyerror!void {
            dest.* = std.mem.eql(u8, value, "true");
        }
    }.parser;
}

fn stringParser(comptime T: type) ValueParser(T) {
    return struct {
        fn parser(dest: *T, value: []const u8) anyerror!void {
            dest.* = value;
        }
    }.parser;
}
