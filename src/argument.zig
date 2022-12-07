const std = @import("std");

pub const Fixed = enum(i32) {
    _,
    pub fn toInt(f: Fixed) i24 {
        return @truncate(i24, @enumToInt(f) >> 8);
    }
    pub fn fromInt(i: i24) Fixed {
        return @intToEnum(Fixed, @as(i32, i) << 8);
    }
    pub fn toDouble(f: Fixed) f64 {
        return @intToFloat(f64, @enumToInt(f)) / 256;
    }
    pub fn fromDouble(d: f64) Fixed {
        return @intToEnum(Fixed, @floatToInt(i32, d * 256));
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
        const ptr = @ptrCast([*]T, @alignCast(4, data));
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
    pub fn len(self: Argument) usize {
        switch (self) {
            .string => |s| {
                const str = s.?;
                return 4 + str.len + 4 - (str.len % 4);
            },
            .uint => |u| {
                // return @sizeOf(@TypeOf(u));
                _ = u;
                return 4;
            },
            else => unreachable,
        }
    }
    pub fn marshal(self: *const Argument, writer: anytype) void {
        _ = writer;

        switch (self) {
            .new_id => |new_id| {
                _ = new_id;
            },
            else => unreachable,
        }
    }
    pub fn unmarshal(typ: ArgumentType, allocator: std.mem.Allocator, data: []const u8) Argument {
        _ = allocator;
        switch (typ) {
            .new_id => {
                const v = std.mem.readIntNative(u32, data[0..4]);
                return Argument{ .new_id = v };
            },
            .uint => {
                const v = std.mem.readIntNative(u32, data[0..4]);
                // std.debug.print("v: {}\n", .{v});
                return Argument{ .uint = v };
            },
            .string => {
                const l = std.mem.readIntNative(u32, data[0..4]);

                // std.debug.print("s len: {}\n", .{l});
                std.debug.assert(l > 0);
                const s = data[4 .. 4 + l - 1];
                // const s = allocator.alloc(u8, l - 1) catch unreachable;
                // std.debug.print("s: {s}\n", .{s});
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

