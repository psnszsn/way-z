const std = @import("std");
const assert = std.debug.assert;
const os = std.os;
const linux = os.linux;
const IO_Uring = linux.IO_Uring;
const io_uring_cqe = linux.io_uring_cqe;
const io_uring_sqe = linux.io_uring_sqe;

pub const IO = struct {
    ring: IO_Uring,

    /// The number of SQEs queued but not yet submitted to the kernel:
    queued: u32 = 0,

    /// The number of SQEs submitted and inflight but not yet completed:
    submitted: u32 = 0,

    /// A linked list of completions that are ready to resume (FIFO):
    completed_head: ?*Completion = null,
    completed_tail: ?*Completion = null,

    const Completion = struct {
        frame: anyframe,
        result: i32 = undefined,
        next: ?*Completion = null,
    };

    pub fn init(entries: u12, flags: u32) !IO {
        return IO{ .ring = try IO_Uring.init(entries, flags) };
    }

    pub fn deinit(self: *IO) void {
        self.ring.deinit();
    }

    pub fn run(self: *IO) !void {
        // Run the event loop while there is IO pending:
        while (self.queued + self.submitted > 0 or self.completed_head != null) {
            // We already use `io_uring_enter()` to submit SQEs so reuse that to wait for CQEs:
            try self.flush_submissions(true);
            // We can now just peek for any CQEs without waiting, and without another syscall:
            try self.flush_completions(false);
            // Resume completion frames only after all completions have been flushed:
            // Loop on a copy of the linked list, having reset the linked list first, so that any
            // synchronous append on resume is executed only the next time round the event loop,
            // without creating an infinite suspend/resume cycle within `while (head)`.
            var head = self.completed_head;
            self.completed_head = null;
            self.completed_tail = null;
            while (head) |completion| {
                head = completion.next;
                resume completion.frame;
            }
        }
        assert(self.completed_head == null);
        assert(self.completed_tail == null);
    }

    fn append_completion(self: *IO, completion: *Completion) void {
        assert(completion.next == null);
        if (self.completed_head == null) {
            assert(self.completed_tail == null);
            self.completed_head = completion;
            self.completed_tail = completion;
        } else {
            self.completed_tail.?.next = completion;
            self.completed_tail = completion;
        }
    }

    fn flush_completions(self: *IO, wait: bool) !void {
        var cqes: [256]io_uring_cqe = undefined;
        var wait_nr: u32 = if (wait) 1 else 0;
        while (true) {
            // Guard against waiting indefinitely (if there are too few requests inflight),
            // especially if this is not the first time round the loop:
            wait_nr = std.math.min(self.submitted, wait_nr);
            const completed = self.ring.copy_cqes(&cqes, wait_nr) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                else => return err,
            };
            self.submitted -= completed;
            for (cqes[0..completed]) |cqe| {
                const completion = @intToPtr(*Completion, @intCast(usize, cqe.user_data));
                completion.result = cqe.res;
                completion.next = null;
                // We do not resume the completion frame here (instead appending to a linked list):
                // * to avoid recursion through `flush_submissions()` and `flush_completions()`,
                // * to avoid unbounded stack usage, and
                // * to avoid confusing stack traces.
                self.append_completion(completion);
            }
            if (completed < cqes.len) break;
        }
    }

    fn flush_submissions(self: *IO, wait: bool) !void {
        var wait_nr: u32 = if (wait) 1 else 0;
        while (true) {
            wait_nr = std.math.min(self.queued + self.submitted, wait_nr);
            _ = self.ring.submit_and_wait(wait_nr) catch |err| switch (err) {
                error.SignalInterrupt => continue,
                // Wait for some completions and then try again:
                // See https://github.com/axboe/liburing/issues/281 re: error.SystemResources.
                // Be careful also that copy_cqes() will flush before entering to wait (it does):
                // https://github.com/axboe/liburing/commit/35c199c48dfd54ad46b96e386882e7ac341314c5
                error.CompletionQueueOvercommitted, error.SystemResources => {
                    try self.flush_completions(true);
                    continue;
                },
                else => return err,
            };
            self.submitted += self.queued;
            self.queued = 0;
            break;
        }
    }

    fn get_sqe(self: *IO) *io_uring_sqe {
        while (true) {
            const sqe = self.ring.get_sqe() catch |err| switch (err) {
                error.SubmissionQueueFull => {
                    var completion = Completion{ .frame = @frame(), .result = 0 };
                    self.append_completion(&completion);
                    suspend {}
                    continue;
                },
            };
            self.queued += 1;
            return sqe;
        }
    }

    pub fn accept(
        self: *IO,
        socket: os.socket_t,
        address: *os.sockaddr,
        address_size: *os.socklen_t,
    ) !os.socket_t {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const sqe = self.get_sqe();
            linux.io_uring_prep_accept(sqe, socket, address, address_size, os.SOCK.CLOEXEC);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .AGAIN => return error.WouldBlock,
                    .BADF => return error.FileDescriptorInvalid,
                    .CONNABORTED => return error.ConnectionAborted,
                    .FAULT => unreachable,
                    .INVAL => return error.SocketNotListening,
                    .MFILE => return error.ProcessFdQuotaExceeded,
                    .NFILE => return error.SystemFdQuotaExceeded,
                    .NOBUFS => return error.SystemResources,
                    .NOMEM => return error.SystemResources,
                    .NOTSOCK => return error.FileDescriptorNotASocket,
                    .OPNOTSUPP => return error.OperationNotSupported,
                    .PERM => return error.PermissionDenied,
                    .PROTO => return error.ProtocolFailure,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                return @intCast(os.socket_t, completion.result);
            }
        }
    }

    pub fn close(self: *IO, fd: os.fd_t) !void {
        var completion = Completion{ .frame = @frame() };
        const sqe = self.get_sqe();
        linux.io_uring_prep_close(sqe, fd);
        sqe.user_data = @ptrToInt(&completion);
        suspend {}
        if (completion.result < 0) {
            switch (@intToEnum(os.E, -completion.result)) {
                .INTR => return, // A success, see https://github.com/ziglang/zig/issues/2425.
                .BADF => return error.FileDescriptorInvalid,
                .DQUOT => return error.DiskQuota,
                .IO => return error.InputOutput,
                .NOSPC => return error.NoSpaceLeft,
                else => |errno| return os.unexpectedErrno(errno),
            }
        } else {
            assert(completion.result == 0);
        }
    }

    pub fn connect(
        self: *IO,
        socket: os.socket_t,
        address: *const os.sockaddr,
        address_size: os.socklen_t,
    ) !void {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const sqe = self.get_sqe();
            linux.io_uring_prep_connect(sqe, socket, address, address_size);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .ACCES => return error.AccessDenied,
                    .ADDRINUSE => return error.AddressInUse,
                    .ADDRNOTAVAIL => return error.AddressNotAvailable,
                    .AFNOSUPPORT => return error.AddressFamilyNotSupported,
                    .AGAIN, .INPROGRESS => return error.WouldBlock,
                    .ALREADY => return error.OpenAlreadyInProgress,
                    .BADF => return error.FileDescriptorInvalid,
                    .CONNREFUSED => return error.ConnectionRefused,
                    .FAULT => unreachable,
                    .ISCONN => return error.AlreadyConnected,
                    .NETUNREACH => return error.NetworkUnreachable,
                    .NOENT => return error.FileNotFound,
                    .NOTSOCK => return error.FileDescriptorNotASocket,
                    .PERM => return error.PermissionDenied,
                    .PROTOTYPE => return error.ProtocolNotSupported,
                    .TIMEDOUT => return error.ConnectionTimedOut,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                assert(completion.result == 0);
                return;
            }
        }
    }

    pub fn fsync(self: *IO, fd: os.fd_t) !void {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const sqe = self.get_sqe();
            linux.io_uring_prep_fsync(sqe, fd, 0);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .BADF => return error.FileDescriptorInvalid,
                    .DQUOT => return error.DiskQuota,
                    .INVAL => return error.ArgumentsInvalid,
                    .IO => return error.InputOutput,
                    .NOSPC => return error.NoSpaceLeft,
                    .ROFS => return error.ReadOnlyFileSystem,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                assert(completion.result == 0);
                return;
            }
        }
    }

    pub fn openat(
        self: *IO,
        dir_fd: os.fd_t,
        pathname: []const u8,
        flags: u32,
        mode: os.mode_t,
    ) !os.fd_t {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const pathname_c = try os.toPosixPath(pathname);
            const sqe = self.get_sqe();
            linux.io_uring_prep_openat(sqe, dir_fd, &pathname_c, flags, mode);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .ACCES => return error.AccessDenied,
                    .BADF => return error.FileDescriptorInvalid,
                    .BUSY => return error.DeviceBusy,
                    .EXIST => return error.PathAlreadyExists,
                    .FAULT => unreachable,
                    .FBIG => return error.FileTooBig,
                    .INVAL => return error.ArgumentsInvalid,
                    .ISDIR => return error.IsDir,
                    .LOOP => return error.SymLinkLoop,
                    .MFILE => return error.ProcessFdQuotaExceeded,
                    .NAMETOOLONG => return error.NameTooLong,
                    .NFILE => return error.SystemFdQuotaExceeded,
                    .NODEV => return error.NoDevice,
                    .NOENT => return error.FileNotFound,
                    .NOMEM => return error.SystemResources,
                    .NOSPC => return error.NoSpaceLeft,
                    .NOTDIR => return error.NotDir,
                    .OPNOTSUPP => return error.FileLocksNotSupported,
                    .OVERFLOW => return error.FileTooBig,
                    .PERM => return error.AccessDenied,
                    .AGAIN => return error.WouldBlock,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                return @intCast(os.fd_t, completion.result);
            }
        }
    }

    pub fn read(self: *IO, fd: os.fd_t, buffer: []u8, offset: u64) !usize {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const sqe = self.get_sqe();
            linux.io_uring_prep_read(sqe, fd, buffer[0..buffer_limit(buffer.len)], offset);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .AGAIN => return error.WouldBlock,
                    .BADF => return error.NotOpenForReading,
                    .CONNRESET => return error.ConnectionResetByPeer,
                    .FAULT => unreachable,
                    .INVAL => return error.Alignment,
                    .IO => return error.InputOutput,
                    .ISDIR => return error.IsDir,
                    .NOBUFS => return error.SystemResources,
                    .NOMEM => return error.SystemResources,
                    .NXIO => return error.Unseekable,
                    .OVERFLOW => return error.Unseekable,
                    .SPIPE => return error.Unseekable,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                return @intCast(usize, completion.result);
            }
        }
    }

    pub fn recv(self: *IO, socket: os.socket_t, buffer: []u8) !usize {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const sqe = self.get_sqe();
            linux.io_uring_prep_recv(sqe, socket, buffer, os.MSG.NOSIGNAL);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .AGAIN => return error.WouldBlock,
                    .BADF => return error.FileDescriptorInvalid,
                    .CONNREFUSED => return error.ConnectionRefused,
                    .FAULT => unreachable,
                    .INVAL => unreachable,
                    .NOMEM => return error.SystemResources,
                    .NOTCONN => return error.SocketNotConnected,
                    .NOTSOCK => return error.FileDescriptorNotASocket,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                return @intCast(usize, completion.result);
            }
        }
    }

    pub fn recvmsg(self: *IO, socket: os.socket_t, msg: *os.msghdr) !usize {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const sqe = self.get_sqe();
            linux.io_uring_prep_recvmsg(sqe, socket, msg, os.MSG.NOSIGNAL);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .AGAIN => return error.WouldBlock,
                    .BADF => return error.FileDescriptorInvalid,
                    .CONNREFUSED => return error.ConnectionRefused,
                    .FAULT => unreachable,
                    .INVAL => unreachable,
                    .NOMEM => return error.SystemResources,
                    .NOTCONN => return error.SocketNotConnected,
                    .NOTSOCK => return error.FileDescriptorNotASocket,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                return @intCast(usize, completion.result);
            }
        }
    }

    pub fn send(self: *IO, socket: os.socket_t, buffer: []const u8) !usize {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const sqe = self.get_sqe();
            linux.io_uring_prep_send(sqe, socket, buffer, os.MSG.NOSIGNAL);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .ACCES => return error.AccessDenied,
                    .AGAIN => return error.WouldBlock,
                    .ALREADY => return error.FastOpenAlreadyInProgress,
                    .AFNOSUPPORT => return error.AddressFamilyNotSupported,
                    .BADF => return error.FileDescriptorInvalid,
                    .CONNRESET => return error.ConnectionResetByPeer,
                    .DESTADDRREQ => unreachable,
                    .FAULT => unreachable,
                    .INVAL => unreachable,
                    .ISCONN => unreachable,
                    .MSGSIZE => return error.MessageTooBig,
                    .NOBUFS => return error.SystemResources,
                    .NOMEM => return error.SystemResources,
                    .NOTCONN => return error.SocketNotConnected,
                    .NOTSOCK => return error.FileDescriptorNotASocket,
                    .OPNOTSUPP => return error.OperationNotSupported,
                    .PIPE => return error.BrokenPipe,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                return @intCast(usize, completion.result);
            }
        }
    }

    pub fn sendmsg(self: *IO, socket: os.socket_t, msg: *const os.msghdr_const) !usize {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const sqe = self.get_sqe();
            linux.io_uring_prep_sendmsg(sqe, socket, msg, os.MSG.NOSIGNAL);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .ACCES => return error.AccessDenied,
                    .AGAIN => return error.WouldBlock,
                    .ALREADY => return error.FastOpenAlreadyInProgress,
                    .AFNOSUPPORT => return error.AddressFamilyNotSupported,
                    .BADF => return error.FileDescriptorInvalid,
                    .CONNRESET => return error.ConnectionResetByPeer,
                    .DESTADDRREQ => unreachable,
                    .FAULT => unreachable,
                    .INVAL => unreachable,
                    .ISCONN => unreachable,
                    .MSGSIZE => return error.MessageTooBig,
                    .NOBUFS => return error.SystemResources,
                    .NOMEM => return error.SystemResources,
                    .NOTCONN => return error.SocketNotConnected,
                    .NOTSOCK => return error.FileDescriptorNotASocket,
                    .OPNOTSUPP => return error.OperationNotSupported,
                    .PIPE => return error.BrokenPipe,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                return @intCast(usize, completion.result);
            }
        }
    }

    pub fn sleep(self: *IO, nanoseconds: u64) !void {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const ts: os.timespec = .{
                .tv_sec = 0,
                .tv_nsec = @intCast(i64, nanoseconds),
            };
            const sqe = self.get_sqe();
            linux.io_uring_prep_timeout(sqe, &ts, 0, 0);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .CANCELED => return error.Canceled,
                    .TIME => return, // A success.
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                unreachable;
            }
        }
    }

    pub fn write(self: *IO, fd: os.fd_t, buffer: []const u8, offset: u64) !usize {
        while (true) {
            var completion = Completion{ .frame = @frame() };
            const sqe = self.get_sqe();
            linux.io_uring_prep_write(sqe, fd, buffer[0..buffer_limit(buffer.len)], offset);
            sqe.user_data = @ptrToInt(&completion);
            suspend {}
            if (completion.result < 0) {
                switch (@intToEnum(os.E, -completion.result)) {
                    .INTR => continue,
                    .AGAIN => return error.WouldBlock,
                    .BADF => return error.NotOpenForWriting,
                    .DESTADDRREQ => return error.NotConnected,
                    .DQUOT => return error.DiskQuota,
                    .FAULT => unreachable,
                    .FBIG => return error.FileTooBig,
                    .INVAL => return error.Alignment,
                    .IO => return error.InputOutput,
                    .NOSPC => return error.NoSpaceLeft,
                    .NXIO => return error.Unseekable,
                    .OVERFLOW => return error.Unseekable,
                    .PERM => return error.AccessDenied,
                    .PIPE => return error.BrokenPipe,
                    .SPIPE => return error.Unseekable,
                    else => |errno| return os.unexpectedErrno(errno),
                }
            } else {
                return @intCast(usize, completion.result);
            }
        }
    }

    pub fn poll_add(self: *IO, fd: os.fd_t, poll_mask: u32) !usize {
        var completion = Completion{ .frame = @frame() };
        const sqe = self.get_sqe();
        linux.io_uring_prep_poll_add(sqe, fd, poll_mask);
        sqe.user_data = @ptrToInt(&completion);
        suspend {}
        if (completion.result < 0) {
            switch (@intToEnum(os.E, -completion.result)) {
                .FAULT => unreachable,
                .INTR => unreachable,
                .INVAL => return error.Alignment,
                .NOMEM => return error.SystemResources,
                else => |errno| return os.unexpectedErrno(errno),
            }
        } else {
            return @intCast(usize, completion.result);
        }
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
    return std.math.min(limit, buffer_len);
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

        try testing.expectApproxEqAbs(@as(f64, ms), @intToFloat(f64, stopped - started), margin);
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
        try testing.expectApproxEqAbs(@as(f64, ms), @intToFloat(f64, stopped - started), margin);
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
    var accept = try await accept_frame;
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
