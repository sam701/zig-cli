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
        .Enum => enumData(ValueType, T),
        else => @compileError("unsupported value type"),
    };
}

fn intData(comptime ValueType: type, comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *DestinationType = @alignCast(@ptrCast(dest));
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

pub const str_true = "true";
pub const str_false = "false";

fn boolData(comptime DestinationType: type) ValueData {
    return .{
        .value_size = @sizeOf(DestinationType),
        .is_bool = true,
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                const dt: *DestinationType = @ptrCast(@alignCast(dest));

                if (std.mem.eql(u8, value, str_true)) {
                    dt.* = true;
                } else if (std.mem.eql(u8, value, str_false)) {
                    dt.* = false;
                } else return error.ParseBoolError;
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

fn enumData(comptime ValueType: type, comptime DestinationType: type) ValueData {
    const edata = @typeInfo(ValueType).Enum;
    return .{
        .value_size = @sizeOf(DestinationType),
        .value_parser = struct {
            fn parser(dest: *anyopaque, value: []const u8) anyerror!void {
                inline for (edata.fields) |field| {
                    if (std.mem.eql(u8, field.name, value)) {
                        const dt: *DestinationType = @ptrCast(@alignCast(dest));
                        dt.* = @field(ValueType, field.name);
                        return;
                    }
                }
                return error.InvalidEnumValue;
            }
        }.parser,
        .type_name = "enum",
    };
}
