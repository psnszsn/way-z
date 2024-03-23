const std = @import("std");

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
    string: [:0]const u8,
    object: u32,
    new_id: u32,
    array: ?*Array,
    fd: i32,
    pub const ArgumentType = std.meta.Tag(Argument);
    pub fn len(self: Argument) u16 {
        const l = switch (self) {
            .string => |str| (std.math.divCeil(usize, 4 + str.len + 1, 4) catch unreachable) * 4,
            .fd => 0,
            inline else => |n| @sizeOf(@TypeOf(n)),
            // else => unreachable,
        };
        return @intCast(l);
    }
    pub fn marshal(self: *const Argument, writer: anytype) !void {
        // std.log.info("arg: {}", .{self});
        switch (self.*) {
            .new_id,
            .object,
            => |inner| {
                try writer.writeInt(u32, inner + 1, .little);
            },
            .uint,
            => |inner| {
                try writer.writeInt(u32, inner, .little);
            },
            .int => |inner| {
                try writer.writeInt(i32, inner, .little);
            },
            .string => |inner| {
                try writer.writeInt(u32, @intCast(inner.len + 1), .little);
                try writer.writeAll(inner);
                std.debug.print("self.le {} {}\n", .{ self.len(), inner.len });
                try writer.writeByteNTimes(0, self.len() - (4 + inner.len));
            },
            .fd => {},
            // .object => |o| {
            //     try writer.writeInt(u32, @intFromPtr(o), .little);
            // },
            else => {
                std.debug.print("arg {}", .{self});
                unreachable;
            },
        }
    }
    pub fn unmarshal(typ: ArgumentType, allocator: std.mem.Allocator, data: []const u8) Argument {
        _ = allocator;
        switch (typ) {
            .new_id => {
                return Argument{ .new_id = @bitCast(data[0..4].*) };
            },
            .object => {
                return Argument{ .object = @bitCast(data[0..4].*) };
            },
            .uint => {
                // std.debug.print("v: {}\n", .{v});
                return Argument{ .uint = @bitCast(data[0..4].*) };
            },
            .int => {
                // std.debug.print("v: {}\n", .{v});
                return Argument{ .int = @bitCast(data[0..4].*) };
            },
            .string => {
                const l: u32 = @bitCast(data[0..4].*);

                // std.debug.print("s len: {}\n", .{l});
                std.debug.assert(l > 0);
                return Argument{
                    .string = data[4..][0 .. l - 1 :0],
                };
            },
            .fixed => {
                const l: i32 = @bitCast(data[0..4].*);
                return Argument{ .fixed = @enumFromInt(l) };
            },
            else => {
                std.debug.print("{}\n", .{typ});
                unreachable;
            },
        }
    }
};

test "marshaling" {
    var buf1: [255]u8 = undefined;
    var fbs1 = std.io.fixedBufferStream(&buf1);
    const arg = Argument{ .string = "frappo" };
    try arg.marshal(fbs1.writer());
    const written = fbs1.getWritten();
    try std.testing.expect(@as(u32, @bitCast(written[0..4].*)) == 7);
    try std.testing.expectEqualSlices(u8, "frappo", written[4..][0..6]);
    try std.testing.expect(written.len % 4 == 0);
}
