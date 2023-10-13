const std = @import("std");

pub const ValueParser = *const fn (dest: *anyopaque, value: []const u8) anyerror!void;

pub const ValueData = struct {
    value_size: usize,
    value_parser: ValueParser,
    is_bool: bool = false,
    type_name: []const u8,
};

pub fn getValueData(comptime T: type) ValueData {
    const ValueType = switch (@typeInfo(T)) {
        .Optional => |oinfo| oinfo.child,
        else => T,
    };
    return switch (@typeInfo(ValueType)) {
        .Int => intData(ValueType, T),
        .Float => floatData(ValueType, T),
        .Bool => boolData(T),
        .Pointer => |pinfo| {
            if (pinfo.size == .Slice and pinfo.child == u8) {
                return stringData(T);
            }
        },
        else => @compileError("unsupported value type"),
    };
}

fn intData(comptime ValueType: type, comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *DestinationType = @ptrCast(@alignCast(dest));
                dt.* = try std.fmt.parseInt(ValueType, value, 10);
            }
        }.parser,
        .type_name = "integer",
    };
}

fn floatData(comptime ValueType: type, comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *DestinationType = @ptrCast(@alignCast(dest));
                dt.* = try std.fmt.parseFloat(ValueType, value);
            }
        }.parser,
        .type_name = "float",
    };
}

fn boolData(comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .is_bool = true,
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *DestinationType = @ptrCast(@alignCast(dest));
                dt.* = std.mem.eql(u8, value, "true");
            }
        }.parser,
        .type_name = "bool",
    };
}

fn stringData(comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *DestinationType = @ptrCast(@alignCast(dest));
                dt.* = value;
            }
        }.parser,
        .type_name = "string",
    };
}
