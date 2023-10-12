const std = @import("std");

pub const ValueParser = *const fn (dest: *anyopaque, value: []const u8) anyerror!void;

pub const ValueData = struct {
    value_size: usize,
    value_parser: ValueParser,
    is_bool: bool = false,
    type_name: []const u8,
};

pub fn getValueData(comptime T: type) ValueData {
    return switch (@typeInfo(T)) {
        .Int => intData(T),
        .Float => floatData(T),
        .Bool => boolData(T),
        .Pointer => |pinfo| {
            if (pinfo.size == .Slice and pinfo.child == u8) {
                return stringData(T);
            }
        },
        else => @compileError("unsupported value type"),
    };
}

fn intData(comptime T: type) ValueData {
    return .{
        .value_size = @sizeOf(T),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *T = @ptrCast(@alignCast(dest));
                dt.* = try std.fmt.parseInt(T, value, 10);
            }
        }.parser,
        .type_name = "integer",
    };
}

fn floatData(comptime T: type) ValueData {
    return .{
        .value_size = @sizeOf(T),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *T = @ptrCast(@alignCast(dest));
                dt.* = try std.fmt.parseFloat(T, value);
            }
        }.parser,
        .type_name = "float",
    };
}

fn boolData(comptime T: type) ValueData {
    return .{
        .value_size = @sizeOf(T),
        .is_bool = true,
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *T = @ptrCast(@alignCast(dest));
                dt.* = std.mem.eql(u8, value, "true");
            }
        }.parser,
        .type_name = "bool",
    };
}

fn stringData(comptime T: type) ValueData {
    return .{
        .value_size = @sizeOf(T),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *T = @ptrCast(@alignCast(dest));
                dt.* = value;
            }
        }.parser,
        .type_name = "string",
    };
}
