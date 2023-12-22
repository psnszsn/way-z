const std = @import("std");
const os = std.os;
const wl = @import("generated/wl.zig");

fn bufferListener(wl_buffer: *wl.Buffer, event: wl.Buffer.Event, buffer: *Buffer) void {
    _ = wl_buffer;

    switch (event) {
        .release => {
            std.debug.assert(buffer.busy == true);
            buffer.busy = false;

            // wl_buffer.destroy();
            // wl_buffer.proxy.display.objects[]
        },
    }
}

var buf: Buffer = undefined;
var buf2: Buffer = undefined;
var curr: *Buffer = &buf;
var v: bool = true;
var done: bool = false;

pub const Buffer = struct {
    width: u32,
    height: u32,
    busy: bool,
    size: usize,
    mmap: []align(4096) u8,
    backing_fd: os.fd_t,
    wl_buffer: *wl.Buffer,
    wl_pool: *wl.ShmPool,

    pub fn get(shm: *wl.Shm, width: u32, height: u32) !*Buffer {
        // std.log.warn("{}x{}", .{ width, height });
        if (!done) {
            buf = try Buffer.init(shm, width, height);
            buf.wl_buffer.set_listener(*Buffer, bufferListener, &buf);
            buf2 = try Buffer.init(shm, width, height);
            buf2.wl_buffer.set_listener(*Buffer, bufferListener, &buf2);
            done = true;
        }
        curr = if (v) &buf else &buf2;
        // curr = &buf;
        v = !v;
        try curr.resize(width, height);

        std.debug.assert(curr.busy == false);
        // std.log.warn("buzy: {} {}", .{ buf.busy, v });
        // std.log.warn("buzy2: {} {}", .{ buf2.busy, v });
        curr.busy = true;
        return curr;
    }

    pub fn init(shm: *wl.Shm, _width: u32, _height: u32) !Buffer {
        const width = if (_width == 0) 300 else _width;
        const height = if (_height == 0) 300 else _height;
        // std.log.info("new buffer {} {}\n", .{ width, height });

        const stride = width * 4;
        const size = stride * height;

        const fd = try os.memfd_create("hello-zig-wayland", 0);
        // defer os.close(fd);
        try os.ftruncate(fd, size);
        const data = try os.mmap(null, size, os.PROT.READ | os.PROT.WRITE, os.MAP.SHARED, fd, 0);
        // os.munmap(data);

        const pool = try shm.create_pool(fd, @intCast(size));
        // defer pool.destroy();

        const buffer = try pool.create_buffer(0, @intCast(width), @intCast(height), @intCast(stride), wl.Shm.Format.argb8888);

        return Buffer{
            .width = @intCast(width),
            .height = @intCast(height),
            .busy = false,
            .size = @intCast(size),
            .mmap = data,
            .backing_fd = fd,
            .wl_buffer = buffer,
            .wl_pool = pool,
        };
    }

    pub fn resize(self: *Buffer, _width: u32, _height: u32) !void {
        const width = if (_width == 0) 300 else _width;
        const height = if (_height == 0) 300 else _height;
        const stride = width * 4;
        const newsize = stride * height;
        if (newsize > self.size) {
            try os.ftruncate(self.backing_fd, newsize);
            self.wl_pool.resize(@intCast(newsize));
            self.size = newsize;
            // self.mmap = unsafe { MmapMut::map_mut(&self.file).unwrap() };
            os.munmap(self.mmap);
            self.mmap = try os.mmap(null, newsize, os.PROT.READ | os.PROT.WRITE, os.MAP.SHARED, self.backing_fd, 0);
        }
        if (self.width != width or self.height != height) {
            self.wl_buffer.destroy();
            self.wl_buffer = try self.wl_pool.create_buffer(0, @intCast(width), @intCast(height), @intCast(stride), wl.Shm.Format.argb8888);
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
