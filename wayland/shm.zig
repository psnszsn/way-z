const std = @import("std");
const os = std.posix;
const wl = @import("generated/wl.zig");
const way = @import("lib.zig");

pub const AutoMemPool = struct {
    pub const FreeItem = struct { offset: u31, len: u31 };
    pool: Pool,
    free_list: std.ArrayListUnmanaged(FreeItem),
    buffers: std.AutoHashMapUnmanaged(wl.Buffer, Buffer) = .{},
    pub fn init(client: *way.Client, shm: wl.Shm) !AutoMemPool {
        const fl = try std.ArrayListUnmanaged(FreeItem).initCapacity(client.allocator, 10);
        var buffers = std.AutoHashMapUnmanaged(wl.Buffer, Buffer){};
        try buffers.ensureTotalCapacity(client.allocator, 6);
        return .{
            .pool = try Pool.init(client, shm, 200, 200),
            .free_list = fl,
            .buffers = buffers,
        };
    }

    fn alloc(self: *AutoMemPool, client: *way.Client, size: u31) u31 {
        if (self.free_list.items.len == 0) {
            self.free_list.appendAssumeCapacity(.{ .offset = 0, .len = @intCast(self.pool.size) });
        }
        for (self.free_list.items) |*item| {
            if (item.len >= size) {
                const r = item.offset;
                item.len -= size;
                item.offset += size;
                return r;
            }
        }
        const pool_size: u31 = @intCast(self.pool.size);
        var r = pool_size;
        var pop = false;
        if (self.free_list.getLastOrNull()) |last| {
            if (last.offset + last.len == self.pool.size) {
                r -= last.len;
                pop = true;
            }
        }

        const target = @max(r + size, pool_size * 2);
        self.pool.resize(client, @intCast(target)) catch unreachable;

        if (pop) _ = self.free_list.pop();

        if (target > r + size) {
            self.free_list.appendAssumeCapacity(.{ .offset = r + size, .len = target - r - size });
        }
        return r;
    }

    fn free(self: *AutoMemPool, offset_r: u31, len_r: u31) void {
        var offset = offset_r;
        var len = len_r;
        {
            const start: usize = for (self.free_list.items, 0..) |item, i| {
                if (item.offset + item.len == offset) {
                    break i;
                }
                if (item.offset == offset + len) {
                    break i;
                }
            } else self.free_list.items.len;

            const l = b: {
                var res: u31 = 0;
                for (self.free_list.items[start..]) |item| {
                    if (item.offset + item.len == offset) {
                        offset = item.offset;
                        len += item.len;
                        res += 1;
                        continue;
                    }
                    if (item.offset == offset + len) {
                        len += item.len;
                        res += 1;
                        continue;
                    }
                    break :b res;
                }
                break :b res;
            };
            // std.log.info("free={} {}", .{ start, l });
            self.free_list.replaceRangeAssumeCapacity(start, l, &[_]FreeItem{.{ .offset = offset, .len = len }});
        }
    }

    pub fn buffer(
        self: *AutoMemPool,
        client: *way.Client,
        width: u31,
        height: u31,
    ) *Buffer {
        const stride = width * 4;
        const size = stride * height;
        const offset = self.alloc(client, size);
        const wl_buffer = client.request(self.pool.wl_pool, .create_buffer, .{
            .offset = @intCast(offset),
            .width = @intCast(width),
            .height = @intCast(height),
            .stride = @intCast(stride),
            .format = wl.Shm.Format.argb8888,
        });

        const res = self.buffers.getOrPutAssumeCapacity(wl_buffer);
        const buf = res.value_ptr;
        buf.* = Buffer{
            .amp = self,
            .width = width,
            .height = height,
            .offset = offset,
            .wl_buffer = wl_buffer,
        };

        const w = struct {
            fn bufferListener(c: *way.Client, _: wl.Buffer, event: wl.Buffer.Event, b: *Buffer) void {
                switch (event) {
                    .release => {
                        // std.log.info("release", .{});
                        c.request(b.wl_buffer, .destroy, {});
                        b.amp.free(b.offset, b.size());
                        _ = b.amp.buffers.remove(b.wl_buffer);
                    },
                }
            }
        };
        client.set_listener(wl_buffer, *Buffer, w.bufferListener, buf);
        return buf;
    }
};

test "free" {
    const fl = try std.ArrayListUnmanaged(AutoMemPool.FreeItem).initCapacity(std.testing.allocator, 10);
    var p = AutoMemPool{ .pool = undefined, .free_list = fl };
    defer p.free_list.clearAndFree(std.testing.allocator);

    {
        p.free_list.appendAssumeCapacity(.{ .offset = 3, .len = 2 });
        p.free(2, 1);
        try std.testing.expectEqualSlices(AutoMemPool.FreeItem, &.{.{ .offset = 2, .len = 3 }}, p.free_list.items);
        p.free_list.clearRetainingCapacity();
    }
    {
        p.free_list.appendAssumeCapacity(.{ .offset = 0, .len = 2 });
        p.free(2, 3);
        try std.testing.expectEqualSlices(AutoMemPool.FreeItem, &.{.{ .offset = 0, .len = 5 }}, p.free_list.items);
        p.free_list.clearRetainingCapacity();
    }
    {
        p.free_list.appendAssumeCapacity(.{ .offset = 0, .len = 2 });
        p.free_list.appendAssumeCapacity(.{ .offset = 4, .len = 2 });
        p.free(2, 2);
        try std.testing.expectEqualSlices(AutoMemPool.FreeItem, &.{.{ .offset = 0, .len = 6 }}, p.free_list.items);
        p.free_list.clearRetainingCapacity();
    }
    {
        p.free_list.appendAssumeCapacity(.{ .offset = 0, .len = 2 });
        p.free(19, 2);
        try std.testing.expectEqualSlices(AutoMemPool.FreeItem, &.{
            .{ .offset = 0, .len = 2 },
            .{ .offset = 19, .len = 2 },
        }, p.free_list.items);
        p.free_list.clearRetainingCapacity();
    }
    std.debug.print("list {any}", .{p.free_list.items});
}

const Pool = struct {
    const max_size = 512 * 1024 * 1024;
    wl_pool: wl.ShmPool = undefined,
    backing_fd: os.fd_t = -1,
    mmap: []align(4096) u8 = undefined,
    size: usize = 0,
    buffer: ?Buffer = null,

    pub fn init(client: *way.Client, shm: wl.Shm, width: u32, height: u32) !Pool {
        const stride = width * 4;
        const size = stride * height;
        // const size = max_size;

        const fd = try os.memfd_create("way-z-shm", 0);
        // defer os.close(fd);
        try os.ftruncate(fd, size);
        const data = try os.mmap(null, size, os.PROT.READ | os.PROT.WRITE, .{ .TYPE = .SHARED }, fd, 0);
        // os.munmap(data);

        const pool = client.request(shm, .create_pool, .{ .fd = fd, .size = @intCast(size) });
        // defer pool.destroy();

        return Pool{
            .size = size,
            .mmap = data,
            .backing_fd = fd,
            .wl_pool = pool,
        };
    }

    pub fn resize(self: *Pool, client: *way.Client, newsize: u32) !void {
        if (newsize > self.size) {
            try os.ftruncate(self.backing_fd, newsize);
            client.request(self.wl_pool, .resize, .{ .size = @intCast(newsize) });
            self.size = newsize;
            os.munmap(self.mmap);
            self.mmap = try os.mmap(null, newsize, os.PROT.READ | os.PROT.WRITE, .{ .TYPE = .SHARED }, self.backing_fd, 0);
        }
    }
};

pub const Buffer = struct {
    amp: *AutoMemPool,
    width: u31,
    height: u31,
    offset: u31,
    wl_buffer: wl.Buffer,

    pub fn size(b: *const Buffer) u31 {
        return b.width * b.height * 4;
    }
    pub fn mem(b: *const Buffer) []align(32) u8 {
        return @alignCast(b.amp.pool.mmap[b.offset..][0..b.size()]);
    }

    pub fn get(client: *way.Client, shm: wl.Shm, _width: u31, _height: u31) !*Buffer {
        const w = struct {
            var amp: ?AutoMemPool = null;
        };
        if (w.amp == null) w.amp = try AutoMemPool.init(client, shm);

        const width = if (_width == 0) 300 else _width;
        const height = if (_height == 0) 300 else _height;
        // std.log.info("pool width={} height={}", .{ width, height });
        return w.amp.?.buffer(client, width, height);
    }
};
