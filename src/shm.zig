const std = @import("std");
const os = std.os;
const wl = @import("generated/wl.zig");

fn bufferListener(wl_buffer: *wl.Buffer, event: wl.Buffer.Event, buffer: *Buffer) void {
    _ = wl_buffer;

    switch (event) {
        .release => {
            std.debug.assert(buffer.busy == true);
            buffer.busy = false;
        },
    }
}

var buf: ?Buffer = undefined;

pub const Pool = struct {
    wl_pool: *wl.ShmPool,
    backing_fd: os.fd_t,
    mmap: []align(4096) u8,
    size: usize,

    pub fn resize(self: *Pool, newsize: u32) !void {
        if (newsize > self.size) {
            try os.ftruncate(self.backing_fd, newsize);
            self.wl_pool.resize(@intCast(newsize));
            self.size = newsize;
            os.munmap(self.mmap);
            self.mmap = try os.mmap(null, newsize, os.PROT.READ | os.PROT.WRITE, .{ .TYPE = .SHARED }, self.backing_fd, 0);
        }
    }
};

pub const Buffer = struct {
    pool: Pool,
    width: u32,
    height: u32,
    busy: bool,
    wl_buffer: *wl.Buffer,

    pub fn get(shm: *wl.Shm, _width: u32, _height: u32) !*Buffer {
        const width = if (_width == 0) 300 else _width;
        const height = if (_height == 0) 300 else _height;

        if (buf == null) {
            buf = try Buffer.init(shm, width, height);
            buf.?.wl_buffer.set_listener(*Buffer, bufferListener, &buf.?);
        }
        if (buf) |*b| {
            if (b.busy) return error.BufferBuzy;
            try b.resize(width, height);
            b.busy = true;
            return b;
        }
        unreachable;
    }

    pub fn init(shm: *wl.Shm, width: u32, height: u32) !Buffer {
        const stride = width * 4;
        const size = stride * height;

        const fd = try os.memfd_create("way-z-shm", 0);
        // defer os.close(fd);
        try os.ftruncate(fd, size);
        const data = try os.mmap(null, size, os.PROT.READ | os.PROT.WRITE, .{ .TYPE = .SHARED }, fd, 0);
        // os.munmap(data);

        const pool = shm.create_pool(fd, @intCast(size));
        // defer pool.destroy();

        const buffer = pool.create_buffer(0, @intCast(width), @intCast(height), @intCast(stride), wl.Shm.Format.argb8888);

        return Buffer{
            .width = @intCast(width),
            .height = @intCast(height),
            .busy = false,
            .wl_buffer = buffer,
            .pool = .{
                .size = @intCast(size),
                .mmap = data,
                .backing_fd = fd,
                .wl_pool = pool,
            },
        };
    }

    pub fn resize(self: *Buffer, width: u32, height: u32) !void {
        const stride = width * 4;
        const newsize = stride * height;
        try self.pool.resize(newsize);
        if (self.width != width or self.height != height) {
            self.wl_buffer.destroy();
            self.wl_buffer = self.pool.wl_pool.create_buffer(0, @intCast(width), @intCast(height), @intCast(stride), wl.Shm.Format.argb8888);
            self.wl_buffer.set_listener(*Buffer, bufferListener, self);
            self.width = width;
            self.height = height;
        }
    }

    pub fn deinit(self: *Buffer) void {
        // self.pool.destroy();
        os.munmap(self.mmap);
    }
};
