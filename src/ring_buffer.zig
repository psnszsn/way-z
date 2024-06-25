const std = @import("std");
const testing = std.testing;

pub fn RingBuffer(comptime _size: comptime_int) type {
    return struct {
        bfr: [_size]u8 = undefined,
        index: usize = 0,
        count: usize = 0,
        const Self = @This();

        pub fn free_space(self: *const Self) usize {
            return self.bfr.len - self.count;
        }

        pub fn wraps(self: *const Self) bool {
            return self.index + self.count > self.bfr.len;
        }

        pub fn preWrapSlice(self: *Self) []u8 {
            const pre_wrap_count = @min(self.count, self.bfr.len - self.index);
            return self.bfr[self.index .. self.index + pre_wrap_count];
        }

        pub fn copy(self: *Self, dest: []u8) usize {
            const pre_wrap_count = @min(self.count, self.bfr.len - self.index, dest.len);
            const post_wrap_count = @min(dest.len - pre_wrap_count, self.count - pre_wrap_count);
            @memcpy(
                dest[0..pre_wrap_count],
                self.bfr[self.index .. self.index + pre_wrap_count],
            );
            if (post_wrap_count > 0) {
                @memcpy(
                    dest[pre_wrap_count .. pre_wrap_count + post_wrap_count],
                    self.bfr[0..post_wrap_count],
                );
            }
            return pre_wrap_count + post_wrap_count;
        }

        pub fn pushSlice(self: *Self, items: []const u8) error{NoSpaceLeft}!void {
            if (self.count + items.len > self.bfr.len) return error.NoSpaceLeft;

            const pre_wrap_start = (self.index + self.count) % self.bfr.len;
            const pre_wrap_count = @min(items.len, self.bfr.len - pre_wrap_start);
            const post_wrap_count = items.len - pre_wrap_count;

            @memcpy(self.bfr[pre_wrap_start..][0..pre_wrap_count], items[0..pre_wrap_count]);
            @memcpy(self.bfr[0..post_wrap_count], items[pre_wrap_count..]);

            self.count += items.len;
        }

        pub fn write(self: *Self, items: []const u8) error{NoSpaceLeft}!usize {
            try pushSlice(self, items);
            return items.len;
        }
        pub const Writer = std.io.Writer(*Self, error{NoSpaceLeft}, write);
        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn consume(self: *Self, size: usize) void {
            std.debug.assert(size <= self.count);
            self.index += size;
            self.index %= self.bfr.len;
            self.count -= size;
        }

        pub fn get_read_iovecs(self: *Self) [2]std.posix.iovec_const {
            const pre_wrap_count = @min(self.count, self.bfr.len - self.index);
            const post_wrap_count = self.count - pre_wrap_count;

            return .{
                .{ .base = self.bfr[self.index..].ptr, .len = pre_wrap_count },
                .{ .base = &self.bfr, .len = post_wrap_count },
            };
        }
        pub fn get_write_iovecs(self: *Self) [2]std.posix.iovec {
            const max_bytes = self.bfr.len - self.count;

            // if (self.count + max_bytes > self.bfr.len) return error.NoSpaceLeft;
            const pre_wrap_start = (self.index + self.count) % self.bfr.len;
            const pre_wrap_count = @min(max_bytes, self.bfr.len - pre_wrap_start);
            const post_wrap_count = max_bytes - pre_wrap_count;

            return .{
                .{ .base = self.bfr[pre_wrap_start..].ptr, .len = pre_wrap_count },
                .{ .base = &self.bfr, .len = post_wrap_count },
            };
        }
    };
}
const Connection = struct {
    socket_fd: std.posix.socket_t,
    in: RingBuffer(512),
};

const Display = struct {
    connection: *Connection,
};

test "asd" {
    const disp = try testing.allocator.create(Display);
    disp.* = .{
        .connection = undefined,
    };
    defer testing.allocator.destroy(disp);

    const connection = try testing.allocator.create(Connection);
    defer testing.allocator.destroy(connection);
    connection.* = .{
        .socket_fd = 7,
        .in = .{},
    };
}

test "writev, readv" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var rb1 = RingBuffer(16){ .bfr = "oaie".* ** 4, .index = 14, .count = 4 };

    var src_file = try tmp.dir.createFile("test.txt", .{ .read = true });
    defer src_file.close();

    var read_iovecs = rb1.get_read_iovecs();
    try src_file.writevAll(&read_iovecs);

    try src_file.seekTo(0);
    const read = try src_file.readToEndAlloc(testing.allocator, 5000);
    defer testing.allocator.free(read);
    try testing.expectEqualStrings(read, "ieoa");

    try src_file.seekTo(0);
    try src_file.writeAll("__$$##");

    try src_file.seekTo(0);
    var write_iovecs = rb1.get_write_iovecs();
    var res = try src_file.readvAll(&write_iovecs);
    try testing.expectEqual(res, 6);
    rb1.count += res;

    std.debug.print("res {}\n", .{res});
    try testing.expectEqualStrings(rb1.bfr[2..8], "__$$##");

    // var cpy = try testing.allocator.alloc(u8, rb1.count);
    // rb1.copy(cpy);
    // std.debug.print("copy {any}\n", .{rb1.bfr});
    // std.debug.print("copy {any}\n", .{cpy});

    rb1.index = 0;
    rb1.count = 0;

    try src_file.seekTo(0);
    write_iovecs = rb1.get_write_iovecs();
    res = try src_file.readvAll(&write_iovecs);
    try testing.expectEqual(res, 6);
    rb1.count += res;
    try testing.expectEqualStrings(rb1.bfr[0..6], "__$$##");
}
