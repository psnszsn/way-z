const std = @import("std");
const assert = std.debug.assert;
const os = std.os;
const linux = os.linux;
pub const IO = struct {
    pub fn init(entries: u12, flags: u32) !IO {
        _ = entries;
        _ = flags;

        return IO{};
    }

    pub fn deinit(self: *IO) void {
        _ = self;
    }

    pub fn run(self: *IO) !void {
        _ = self;
    }

    pub fn accept(
        self: *IO,
        socket: os.socket_t,
        address: *os.sockaddr,
        address_size: *os.socklen_t,
    ) !os.socket_t {
        _ = self;
        return os.accept(socket, address, address_size);
    }

    pub fn close(self: *IO, fd: os.fd_t) !void {
        _ = self;
        return os.close(fd);
    }

    pub fn connect(
        self: *IO,
        socket: os.socket_t,
        address: *const os.sockaddr,
        address_size: os.socklen_t,
    ) !void {
        _ = self;
        return os.connect(socket, address, address_size);
    }

    pub fn fsync(self: *IO, fd: os.fd_t) !void {
        _ = self;
        _ = fd;
    }

    pub fn openat(
        self: *IO,
        dir_fd: os.fd_t,
        pathname: []const u8,
        flags: u32,
        mode: os.mode_t,
    ) !os.fd_t {
        _ = self;
        _ = dir_fd;
        _ = pathname;
        _ = flags;
        _ = mode;
    }

    pub fn read(self: *IO, fd: os.fd_t, buffer: []u8, offset: u64) !usize {
        _ = self;
        _ = fd;
        _ = buffer;
        _ = offset;
    }

    pub fn recv(self: *IO, socket: os.socket_t, buffer: []u8) !usize {
        _ = self;
        _ = socket;
        _ = buffer;
    }

    pub fn recvmsg(self: *IO, socket: os.socket_t, msg: *os.msghdr) !usize {
        _ = self;
        return linux.recvmsg(socket, msg, os.MSG.NOSIGNAL);
    }

    pub fn send(self: *IO, socket: os.socket_t, buffer: []const u8) !usize {
        _ = self;
        _ = socket;
        _ = buffer;
    }

    pub fn sendmsg(self: *IO, socket: os.socket_t, msg: *const os.msghdr_const) !usize {
        _ = self;

        return os.sendmsg(socket, msg, os.MSG.NOSIGNAL);
    }

    pub fn sleep(self: *IO, nanoseconds: u64) !void {
        _ = self;
        _ = nanoseconds;

        // while (true) {
        //     var completion = Completion{ .frame = @frame() };
        //     const ts: os.timespec = .{
        //         .tv_sec = 0,
        //         .tv_nsec = @as(i64, @intCast(nanoseconds)),
        //     };
        //     const sqe = self.get_sqe();
        //     linux.io_uring_prep_timeout(sqe, &ts, 0, 0);
        //     sqe.user_data = @intFromPtr(&completion);
        //     xsuspend();
        //     if (completion.result < 0) {
        //         switch (@as(os.E, @enumFromInt(-completion.result))) {
        //             .INTR => continue,
        //             .CANCELED => return error.Canceled,
        //             .TIME => return, // A success.
        //             else => |errno| return os.unexpectedErrno(errno),
        //         }
        //     } else {
        //         unreachable;
        //     }
        // }
    }

    pub fn write(self: *IO, fd: os.fd_t, buffer: []const u8, offset: u64) !usize {
        _ = self;
        _ = fd;
        _ = buffer;
        _ = offset;
    }

    pub fn poll_add(self: *IO, fd: os.fd_t, poll_mask: u32) !usize {
        _ = self;
        _ = fd;
        _ = poll_mask;
    }
};

pub fn buffer_limit(buffer_len: usize) usize {
    // Linux limits how much may be written in a `pwrite()/pread()` call, which is `0x7ffff000` on
    // both 64-bit and 32-bit systems, due to using a signed C int as the return value, as well as
    // stuffing the errno codes into the last `4096` values.
    // Darwin limits writes to `0x7fffffff` bytes, more than that returns `EINVAL`.
    // The corresponding POSIX limit is `std.math.maxInt(isize)`.
    const builtin = @import("builtin");
    const limit = switch (builtin.target.os.tag) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos => std.math.maxInt(i32),
        else => std.math.maxInt(isize),
    };
    return @min(limit, buffer_len);
}

const testing = std.testing;

fn test_write_fsync_read(io: *IO) !void {
    const path = "test_io_write_fsync_read";
    const file = try std.fs.cwd().createFile(path, .{ .read = true, .truncate = true });
    defer file.close();
    defer std.fs.cwd().deleteFile(path) catch {};
    const fd = file.handle;

    const buffer_write = [_]u8{97} ** 20;
    var buffer_read = [_]u8{98} ** 20;

    const bytes_written = try io.write(fd, buffer_write[0..], 10);
    try testing.expectEqual(@as(usize, buffer_write.len), bytes_written);

    try io.fsync(fd);

    const bytes_read = try io.read(fd, buffer_read[0..], 10);
    try testing.expectEqual(@as(usize, buffer_read.len), bytes_read);

    try testing.expectEqualSlices(u8, buffer_write[0..], buffer_read[0..]);
}

fn test_openat_close(io: *IO) !void {
    const path = "test_io_openat_close";
    defer std.fs.cwd().deleteFile(path) catch {};

    const fd = try io.openat(linux.AT.FDCWD, path, os.O.CLOEXEC | os.O.RDWR | os.O.CREAT, 0o666);
    defer io.close(fd) catch unreachable;
    try testing.expect(fd > 0);
}

fn test_sleep(io: *IO) !void {
    {
        const ms = 100;
        const margin = 5;

        const started = std.time.milliTimestamp();
        try io.sleep(ms * std.time.ns_per_ms);
        const stopped = std.time.milliTimestamp();

        try testing.expectApproxEqAbs(@as(f64, ms), @as(f64, @floatFromInt(stopped - started)), margin);
    }
    {
        const frames = try testing.allocator.alloc(@Frame(test_sleep_coroutine), 10);
        defer testing.allocator.free(frames);

        const ms = 27;
        const margin = 5;
        var count: usize = 0;

        const started = std.time.milliTimestamp();
        for (frames) |*frame| {
            frame.* = async test_sleep_coroutine(io, ms, &count);
        }
        for (frames) |*frame| {
            try await frame;
        }
        const stopped = std.time.milliTimestamp();

        try testing.expect(count == frames.len);
        try testing.expectApproxEqAbs(@as(f64, ms), @as(f64, @floatFromInt(stopped - started)), margin);
    }
}

fn test_sleep_coroutine(io: *IO, ms: u64, count: *usize) !void {
    try io.sleep(ms * std.time.ns_per_ms);
    count.* += 1;
}

fn test_accept_connect_send_receive(io: *IO) !void {
    const address = try std.net.Address.parseIp4("127.0.0.1", 3131);
    const kernel_backlog = 1;
    const server = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
    defer io.close(server) catch unreachable;
    try os.setsockopt(server, os.SOL.SOCKET, os.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try os.bind(server, &address.any, address.getOsSockLen());
    try os.listen(server, kernel_backlog);

    const client = try os.socket(address.any.family, os.SOCK.STREAM | os.SOCK.CLOEXEC, 0);
    defer io.close(client) catch unreachable;

    const buffer_send = [_]u8{ 1, 0, 1, 0, 1, 0, 1, 0, 1, 0 };
    var buffer_recv = [_]u8{ 0, 1, 0, 1, 0 };

    var accept_address: os.sockaddr = undefined;
    var accept_address_size: os.socklen_t = @sizeOf(@TypeOf(accept_address));

    var accept_frame = async io.accept(server, &accept_address, &accept_address_size);
    try io.connect(client, &address.any, address.getOsSockLen());
    const accept = try await accept_frame;
    defer io.close(accept) catch unreachable;

    const send_size = try io.send(client, buffer_send[0..]);
    try testing.expectEqual(buffer_send.len, send_size);

    const recv_size = try io.recv(accept, buffer_recv[0..]);
    try testing.expectEqual(buffer_recv.len, recv_size);

    try testing.expectEqualSlices(u8, buffer_send[0..buffer_recv.len], buffer_recv[0..]);
}

fn test_submission_queue_full(io: *IO) !void {
    var a = async io.sleep(0);
    var b = async io.sleep(0);
    var c = async io.sleep(0);
    try await a;
    try await b;
    try await c;
}

fn test_run(entries: u12, comptime test_fn: anytype) void {
    var io = IO.init(entries, 0) catch unreachable;
    defer io.deinit();
    var frame = async test_fn(&io);
    io.run() catch unreachable;
    nosuspend await frame catch unreachable;
}

test "write/fsync/read" {
    test_run(32, test_write_fsync_read);
}

test "openat/close" {
    test_run(32, test_openat_close);
}

test "sleep" {
    test_run(32, test_sleep);
}

test "accept/connect/send/receive" {
    test_run(32, test_accept_connect_send_receive);
}

test "SubmissionQueueFull" {
    test_run(1, test_submission_queue_full);
}
