const std = @import("std");

const native_endian = @import("builtin").cpu.arch.endian();

pub const Fixed = enum(i32) {
    _,
    pub fn toInt(f: Fixed) i24 {
        return @as(i24, @truncate(@intFromEnum(f) >> 8));
    }
    pub fn fromInt(i: i24) Fixed {
        return @as(Fixed, @enumFromInt(@as(i32, i) << 8));
    }
    pub fn toDouble(f: Fixed) f64 {
        return @as(f64, @floatFromInt(@intFromEnum(f))) / 256;
    }
    pub fn fromDouble(d: f64) Fixed {
        return @as(Fixed, @enumFromInt(@as(i32, @intFromFloat(d * 256))));
    }
};

pub const Array = extern struct {
    size: usize,
    alloc: usize,
    data: ?*anyopaque,

    /// Does not clone memory
    pub fn fromArrayList(comptime T: type, list: std.ArrayList(T)) Array {
        return Array{
            .size = list.items.len * @sizeOf(T),
            .alloc = list.capacity * @sizeOf(T),
            .data = list.items.ptr,
        };
    }

    pub fn slice(array: Array, comptime T: type) []T {
        const data = array.data orelse return &[0]T{};
        // The wire protocol/libwayland only guarantee 32-bit word alignment.
        const ptr: [*]T = @ptrCast(@alignCast(data));
        return ptr[0..@divExact(array.size, @sizeOf(T))];
    }
};

pub const Argument = union(enum) {
    int: i32,
    uint: u32,
    fixed: Fixed,
    string: ?[]const u8,
    object: ?*anyopaque,
    new_id: u32,
    array: ?*Array,
    fd: i32,
    pub const ArgumentType = std.meta.Tag(Argument);
    pub fn len(self: Argument) u16 {
        const l = switch (self) {
            .string => |s| blk: {
                const str = s.?;
                break :blk 4 + str.len + 4 - (str.len % 4);
            },
            .new_id => |n| @sizeOf(@TypeOf(n)),
            .uint => |_| 4,
            else => unreachable,
        };
        return @as(u16, @intCast(l));
    }
    pub fn marshal(self: *const Argument, writer: anytype) !void {
        switch (self.*) {
            .new_id => |new_id| {
                try writer.writeInt(u32, new_id, .little);
            },
            else => unreachable,
        }
    }
    pub fn unmarshal(typ: ArgumentType, allocator: std.mem.Allocator, data: []const u8) Argument {
        _ = allocator;
        switch (typ) {
            .new_id => {
                const v = std.mem.readInt(u32, data[0..4], native_endian);
                return Argument{ .new_id = v };
            },
            .uint => {
                const v = std.mem.readInt(u32, data[0..4], native_endian);
                // std.debug.print("v: {}\n", .{v});
                return Argument{ .uint = v };
            },
            .string => {
                const l = std.mem.readInt(u32, data[0..4], native_endian);

                // std.debug.print("s len: {}\n", .{l});
                std.debug.assert(l > 0);
                const s = data[4 .. 4 + l - 1];
                // const s = allocator.alloc(u8, l - 1) catch unreachable;
                std.debug.print("s: {s}\n", .{s});
                // Skip sentinel + padding
                // l = l-1
                // s = argdata.read(l).decode('utf-8')
                // argdata.read(4 - (l % 4))
                return Argument{ .string = s };
            },
            else => unreachable,
        }
    }
};
