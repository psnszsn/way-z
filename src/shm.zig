const std = @import("std");
const os = std.posix;
const wl = @import("generated/wl.zig");
const way = @import("lib.zig");

fn bufferListener(_: *way.Client, _: wl.Buffer, event: wl.Buffer.Event, buffer: *Buffer) void {
    switch (event) {
        .release => {
            // std.log.warn("release {}x{}", .{ buffer.width, buffer.height });
            std.debug.assert(buffer.busy == true);
            buffer.busy = false;
        },
    }
}

pub const Pool = struct {
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

    pub fn get_buffer(pool: *Pool, client: *way.Client, width: u32, height: u32) *Buffer {
        const stride = width * 4;
        // std.debug.assert(stride * height <= pool.size);
        if (pool.size < stride * height) {
            pool.resize(client, stride * height) catch unreachable;
        }

        defer pool.buffer.?.busy = true;

        if (pool.buffer) |*bfr| {
            if (bfr.width == width and bfr.height == height) {
                std.debug.assert(bfr.busy == false);
                return bfr;
            }
            client.request(bfr.wl_buffer, .destroy, {});
        }

        const wl_buffer = client.request(pool.wl_pool, .create_buffer, .{
            .offset = 0,
            .width = @intCast(width),
            .height = @intCast(height),
            .stride = @intCast(stride),
            .format = wl.Shm.Format.argb8888,
        });
        pool.buffer = .{
            .pool = pool,
            .width = @intCast(width),
            .height = @intCast(height),
            .busy = false,
            .wl_buffer = wl_buffer,
        };

        client.set_listener(wl_buffer, *Buffer, bufferListener, &pool.buffer.?);
        return &pool.buffer.?;
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
    pool: *Pool,
    width: u32,
    height: u32,
    busy: bool,
    wl_buffer: wl.Buffer,

    pub fn get(client: *way.Client, shm: wl.Shm, _width: u32, _height: u32) !*Buffer {
        const w = struct {
            var pools: [1]Pool = [1]Pool{.{}} ** 1;
        };

        const width = if (_width == 0) 300 else _width;
        const height = if (_height == 0) 300 else _height;
        std.log.info("pool width={} height={}", .{ width, height });

        for (&w.pools) |*pool| {
            std.log.info("pool fd {}", .{pool.backing_fd});
        }
        for (&w.pools) |*pool| {
            if (pool.backing_fd == -1) pool.* = try Pool.init(client, shm, width, height);
            // if (pool.size < width * height * 4) continue;
            if (pool.buffer != null and pool.buffer.?.busy) continue;
            // if (pool.buffer == null) return pool.get_buffer(client, width, height);

            return pool.get_buffer(client, width, height);
        }
        return error.BufferBuzy;
    }

    pub fn resize(self: *Buffer, width: u32, height: u32) !void {
        const stride = width * 4;
        const newsize = stride * height;
        try self.pool.resize(newsize);
        if (self.width != width or self.height != height) {
            self.client.request(self.wl_buffer, .destroy, {});
            self.wl_buffer = self.client.request(self.pool.wl_pool, .create_buffer, .{
                .offset = 0,
                .width = @intCast(width),
                .height = @intCast(height),
                .stride = @intCast(stride),
                .format = wl.Shm.Format.argb8888,
            });
            self.client.set_listener(self.wl_buffer, *Buffer, bufferListener, self);
            self.width = width;
            self.height = height;
        }
    }

    // pub fn get_mem(self: *Buffer) []align(4096) u8 {
    //     const pool: *Pool = @alignCast(@fieldParentPtr("buffer", @as(*?Buffer, @ptrCast(self))));
    //     return pool.mmap;
    // }
};
