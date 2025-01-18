const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ValueParseError = error{
    InvalidValue,
} || std.mem.Allocator.Error;
pub const ValueParser = *const fn (dest: *anyopaque, value: []const u8, alloc: Allocator) ValueParseError!void;

pub const ValueData = struct {
    value_size: usize,
    value_parser: ValueParser,
    is_bool: bool = false,
    type_name: []const u8,
};

pub fn getValueData(comptime T: type) ValueData {
    const ValueType = switch (@typeInfo(T)) {
        .optional => |oinfo| oinfo.child,
        else => T,
    };
    return switch (@typeInfo(ValueType)) {
        .int => intData(ValueType, T),
        .float => floatData(ValueType, T),
        .bool => boolData(T),
        .pointer => |pinfo| {
            if (pinfo.size == .slice and pinfo.child == u8) {
                return stringData(T);
            }
        },
        .@"enum" => enumData(ValueType, T),
        else => @compileError("unsupported value type"),
    };
}

fn intData(comptime ValueType: type, comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8, alloc: Allocator) ValueParseError!void {
                _ = alloc;
                const dt: *DestinationType = @alignCast(@ptrCast(dest));
                dt.* = std.fmt.parseInt(ValueType, value, 10) catch return error.InvalidValue;
            }
        }.parser,
        .type_name = "integer",
    };
}

fn floatData(comptime ValueType: type, comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8, alloc: Allocator) ValueParseError!void {
                _ = alloc;
                const dt: *DestinationType = @ptrCast(@alignCast(dest));
                dt.* = std.fmt.parseFloat(ValueType, value) catch return error.InvalidValue;
            }
        }.parser,
        .type_name = "float",
    };
}

pub const str_true = "true";
pub const str_false = "false";

fn boolData(comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .is_bool = true,
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8, alloc: Allocator) ValueParseError!void {
                _ = alloc;
                const dt: *DestinationType = @ptrCast(@alignCast(dest));

                if (std.mem.eql(u8, value, str_true)) {
                    dt.* = true;
                } else if (std.mem.eql(u8, value, str_false)) {
                    dt.* = false;
                } else return error.InvalidValue;
            }
        }.parser,
        .type_name = "bool",
    };
}

fn stringData(comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8, alloc: Allocator) ValueParseError!void {
                const dt: *DestinationType = @ptrCast(@alignCast(dest));
                const cpy = try alloc.dupe(u8, value);
                dt.* = cpy;
            }
        }.parser,
        .type_name = "string",
    };
}

fn enumData(comptime ValueType: type, comptime DestinationType: type) ValueData {
    const edata = @typeInfo(ValueType).@"enum";
    return .{
        .value_size = @sizeOf(DestinationType),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8, alloc: Allocator) ValueParseError!void {
                _ = alloc;
                inline for (edata.fields) |field| {
                    if (std.mem.eql(u8, field.name, value)) {
                        const dt: *DestinationType = @ptrCast(@alignCast(dest));
                        dt.* = @field(ValueType, field.name);
                        return;
                    }
                }
                return error.InvalidValue;
            }
        }.parser,
        .type_name = "enum",
    };
}
