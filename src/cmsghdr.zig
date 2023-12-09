// https://github.com/tupleapp/tuple-launch/blob/master/cmsghdr.zig

const std = @import("std");

/// TODO: move this to std
/// This definition enables the use of Zig types with a cmsghdr structure.
/// The oddity of this layout is that the data must be aligned to @sizeOf(usize)
/// rather than its natural alignment.
pub fn Cmsghdr(comptime T: type) type {
    const Header = extern struct {
        len: usize,
        level: c_int,
        type: c_int,
    };

    const data_align = @sizeOf(usize);
    const data_offset = std.mem.alignForward(usize, @sizeOf(Header), data_align);

    return extern struct {
        const Self = @This();

        bytes: [data_offset + @sizeOf(T)]u8 align(@alignOf(Header)),

        pub fn init(args: struct {
            level: c_int,
            type: c_int,
            data: ?T = null,
        }) Self {
            var self: Self = undefined;
            self.headerPtr().* = .{
                .len = data_offset + @sizeOf(T),
                .level = args.level,
                .type = args.type,
            };
            if (args.data) |data| {
                self.dataPtr().* = data;
            }
            return self;
        }

        pub fn headerPtr(self: *Self) *Header {
            return @ptrCast(self);
        }
        pub fn dataPtr(self: *Self) *align(data_align) T {
            return @ptrCast(self.bytes[data_offset..]);
        }
    };
}

test {
    std.testing.refAllDecls(Cmsghdr([3]std.os.fd_t));
}

test "sendmsg" {
    const os = std.os;
    var address_server = try std.net.Address.parseIp4("127.0.0.1", 0);

    // const fd = try std.os.socket(os.linux.AF.UNIX, os.linux.SOCK.STREAM, 0);
    // var buf: [std.os.PATH_MAX]u8 = undefined;
    // const a = try std.fmt.bufPrint(&buf, "{s}/{s}", .{ xdg_runtime_dir, wl_display });
    //
    // var addr = try std.net.Address.initUnix(a);
    // try io.connect(fd, &addr.any, addr.getOsSockLen());

    const server = try os.socket(address_server.any.family, os.SOCK.DGRAM, 0);
    defer os.close(server);
    try os.setsockopt(server, os.SOL.SOCKET, os.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));
    try os.setsockopt(server, os.SOL.SOCKET, os.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try os.bind(server, &address_server.any, address_server.getOsSockLen());

    // set address_server to the OS-chosen IP/port.
    var slen: os.socklen_t = address_server.getOsSockLen();
    try os.getsockname(server, &address_server.any, &slen);

    const client = try os.socket(address_server.any.family, os.SOCK.DGRAM, 0);
    defer os.close(client);
    const buffer_send = [_]u8{42} ** 128;
    const iovecs_send = [_]os.iovec_const{
        os.iovec_const{ .iov_base = &buffer_send, .iov_len = buffer_send.len },
    };
    const msg_send = os.msghdr_const{
        .name = &address_server.any,
        .namelen = address_server.getOsSockLen(),
        .iov = &iovecs_send,
        .iovlen = 1,
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    const sqe_sendmsg = try os.sendmsg(client, &msg_send, 0);

    var buffer_recv = [_]u8{0} ** 128;
    var iovecs_recv = [_]os.iovec{
        os.iovec{ .iov_base = &buffer_recv, .iov_len = buffer_recv.len },
    };
    const addr = [_]u8{0} ** 4;
    var address_recv = std.net.Address.initIp4(addr, 0);
    var msg_recv: os.msghdr = os.msghdr{
        .name = &address_recv.any,
        .namelen = address_recv.getOsSockLen(),
        .iov = &iovecs_recv,
        .iovlen = 1,
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    const sqe_recvmsg = os.linux.recvmsg(server, &msg_recv, 0);

    try std.testing.expectEqual(buffer_send.len, sqe_sendmsg);
    try std.testing.expectEqual(buffer_recv.len, sqe_recvmsg);

    try std.testing.expectEqualSlices(u8, buffer_send[0..buffer_recv.len], buffer_recv[0..]);

    // sqe_sendmsg.flags |= os.linux.IOSQE_IO_LINK;
    // try std.testing.expectEqual(os.linux.IORING_OP.SENDMSG, sqe_sendmsg.opcode);
    std.debug.print("result {}\n", .{sqe_sendmsg});
    // try std.testing.expectEqual(client, sqe_sendmsg.fd);
}
