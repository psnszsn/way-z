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
        var fl = try std.ArrayListUnmanaged(FreeItem).initCapacity(client.allocator, 10);

        var buffers = std.AutoHashMapUnmanaged(wl.Buffer, Buffer){};
        try buffers.ensureTotalCapacity(client.allocator, 16);
        const pool = try Pool.init(client, shm, 200, 200);
        fl.appendAssumeCapacity(.{ .offset = 0, .len = @intCast(pool.size) });
        return .{
            .pool = pool,
            .free_list = fl,
            .buffers = buffers,
        };
    }
    pub fn deinit(amp: *AutoMemPool, client: *way.Client) void {
        const w = struct {
            fn buffer_listener(c: *way.Client, wlbuf: wl.Buffer, event: wl.Buffer.Event, _: ?*anyopaque) void {
                switch (event) {
                    .release => {
                        c.request(wlbuf, .destroy, {});
                    },
                }
            }
        };

        // change the listener for in flight buffers
        var it = amp.buffers.keyIterator();
        while (it.next()) |wl_buffer| {
            client.set_listener(wl_buffer.*, ?*anyopaque, w.buffer_listener, null);
        }
        amp.pool.deinit(client);
        amp.free_list.deinit(client.allocator);
        amp.buffers.deinit(client.allocator);
    }

    fn alloc(amp: *AutoMemPool, client: *way.Client, size: u31) u31 {
        for (amp.free_list.items) |*item| {
            if (item.len >= size) {
                const r = item.offset;
                item.*.len -= size;
                item.*.offset += size;
                return r;
            }
        }
        // if (true) @panic("TODO");
        const pool_size: u31 = @intCast(amp.pool.size);
        var r = pool_size;
        var pop = false;
        if (amp.free_list.getLastOrNull()) |last| {
            if (last.offset + last.len == amp.pool.size) {
                r -= last.len;
                pop = true;
            }
        }

        const target = @max(r + size, pool_size * 2);
        amp.pool.resize(client, target) catch unreachable;

        if (pop) _ = amp.free_list.pop();

        if (target > r + size) {
            amp.free_list.appendAssumeCapacity(.{ .offset = r + size, .len = target - r - size });
        }
        return r;
    }

    fn free(amp: *AutoMemPool, offset_r: u31, len_r: u31) void {
        var offset = offset_r;
        var len = len_r;
        {
            const start: usize = for (amp.free_list.items, 0..) |item, i| {
                if (item.offset + item.len == offset) {
                    break i;
                }
                if (item.offset == offset + len) {
                    break i;
                }
            } else amp.free_list.items.len;

            const l = b: {
                var res: u31 = 0;
                for (amp.free_list.items[start..]) |item| {
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
            amp.free_list.replaceRangeAssumeCapacity(start, l, &[_]FreeItem{.{ .offset = offset, .len = len }});
        }
    }

    fn dumpfl(amp: *const AutoMemPool) void {
        for (amp.free_list.items) |item| {
            std.debug.print("[{}:{}] ", .{ item.offset, item.len });
        }
        std.debug.print("\n", .{});
    }

    fn dump(amp: *const AutoMemPool) void {
        var it = amp.buffers.iterator();
        std.debug.print("amp {}:\n", .{@intFromPtr(amp)});
        while (it.next()) |b| {
            std.debug.print("\t{} ::: {} {} \n", .{
                b.key_ptr.*,
                b.value_ptr.offset,
                b.value_ptr.size(),
            });
        }
    }

    pub fn buffer(
        amp: *AutoMemPool,
        client: *way.Client,
        width: u31,
        height: u31,
    ) *Buffer {
        const stride = width * 4;
        const size = stride * height;
        const offset = amp.alloc(client, size);
        const wl_buffer = client.request(amp.pool.wl_pool, .create_buffer, .{
            .offset = @intCast(offset),
            .width = @intCast(width),
            .height = @intCast(height),
            .stride = @intCast(stride),
            .format = wl.Shm.Format.argb8888,
        });

        const res = amp.buffers.getOrPutAssumeCapacity(wl_buffer);
        const buf = res.value_ptr;
        buf.* = Buffer{
            .amp = amp,
            .width = width,
            .height = height,
            .offset = offset,
            .wl_buffer = wl_buffer,
        };

        const w = struct {
            fn buffer_listener(c: *way.Client, wlbuf: wl.Buffer, event: wl.Buffer.Event, _amp: *AutoMemPool) void {
                switch (event) {
                    .release => {
                        c.request(wlbuf, .destroy, {});
                        const b = _amp.buffers.get(wlbuf).?;
                        std.debug.assert(wlbuf == b.wl_buffer);
                        _amp.free(b.offset, b.size());
                        _ = _amp.buffers.remove(wlbuf);
                    },
                }
            }
        };
        client.set_listener(wl_buffer, *AutoMemPool, w.buffer_listener, amp);
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
    mmap: []align(std.heap.page_size_min) u8 = undefined,
    size: usize = 0,

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

    pub fn deinit(self: *Pool, client: *way.Client) void {
        client.request(self.wl_pool, .destroy, {});
        os.munmap(self.mmap);
        os.close(self.backing_fd);
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
    pub fn mem(b: *const Buffer) []align(4) u8 {
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
