const std = @import("std");
const linux = std.os.linux;
const Proxy = @import("proxy.zig").Proxy;
const xev = @import("xev");
const IO = @import("lib.zig").IO;
const RingBuffer = @import("ring_buffer.zig").RingBuffer;
const Argument = @import("argument.zig").Argument;
const wl = @import("generated/wl.zig");
const Cmsghdr = @import("cmsghdr.zig").Cmsghdr;

pub const Connection = struct {
    socket_fd: std.os.socket_t,
    in: RingBuffer(1024) = .{},
    out: RingBuffer(1024) = .{},
    fd_in: RingBuffer(512) = .{},
    fd_out: RingBuffer(512) = .{},
    client: *Client,
    loop: xev.IO_Uring.Loop,

    recv_c: xev.Completion = .{},
    recv_cancel_c: xev.Completion = .{},
    recv_iovecs: [2]std.os.iovec = undefined,
    recv_msghdr: std.os.msghdr = undefined,

    send_c: xev.Completion = .{},
    send_iovecs: [2]std.os.iovec_const = undefined,
    send_msghdr: std.os.msghdr_const = undefined,
    send_cmsg: Cmsghdr([5]std.os.fd_t) = undefined,

    is_running: bool = true,

    pub fn cancel_recv(self: *Connection) void {
        if (self.recv_c.state() != .active) return;
        std.log.info("cancel_recv", .{});
        self.loop.cancel(
            &self.recv_c,
            &self.recv_cancel_c,
            void,
            null,
            (struct {
                fn callback(ud: ?*void, l: *xev.Loop, c: *xev.Completion, r: xev.CancelError!void) xev.CallbackAction {
                    std.log.info("r: {!}", .{r});
                    r catch unreachable;
                    _ = c;
                    _ = l;
                    _ = ud;
                    return .disarm;
                }
            }).callback,
        );
    }

    pub fn recv(self: *Connection) void {
        self.recv_iovecs = self.in.get_write_iovecs();
        self.recv_msghdr = std.os.msghdr{
            .name = null,
            .namelen = 0,
            .iov = &self.recv_iovecs,
            .iovlen = 2,
            .control = null,
            .controllen = 0,
            .flags = 0,
        };

        self.recv_c = .{
            .op = .{
                .recvmsg = .{
                    .fd = self.socket_fd,
                    .msghdr = &self.recv_msghdr,
                },
            },
            .userdata = self,
            .callback = recv_cb,
        };

        self.loop.add(&self.recv_c);
    }

    fn recv_cb(ud: ?*anyopaque, _: *xev.Loop, _: *xev.Completion, r: xev.Result) xev.CallbackAction {
        const connection = @as(*Connection, @ptrCast(@alignCast(ud.?)));
        connection.in.count += r.recvmsg catch |err| switch (err) {
            error.Canceled => return .disarm,
            else => unreachable,
        };

        connection.client.consumeEvents() catch unreachable;

        if (connection.is_running) {
            if (connection.can_send()) connection.send() else {}
            connection.recv();
        }
        return .disarm;
    }
    pub fn can_send(self: *Connection) bool {
        if (self.send_c.state() == .active) return false;
        return !(self.out.count == 0 and self.fd_out.count == 0);
    }
    pub fn send(self: *Connection) void {
        if (self.send_c.state() == .active) unreachable;
        if (self.out.count == 0 and self.fd_out.count == 0) return;
        std.log.info("!!sending {}", .{self.out.count});
        self.send_iovecs = self.out.get_read_iovecs();
        self.send_cmsg = Cmsghdr([5]std.os.fd_t).init(.{
            .level = std.os.SOL.SOCKET,
            .type = 1, //SCM_RIGHTS
        });
        const len = self.fd_out.copy(std.mem.asBytes(self.send_cmsg.dataPtr()));
        self.fd_out.consume(len);
        const cmsg_len: u32 = @intCast(@TypeOf(self.send_cmsg).data_offset + len);
        self.send_cmsg.headerPtr().len = cmsg_len;
        // std.debug.print("fd len {}\n", .{len});

        self.send_msghdr = std.os.msghdr_const{
            .name = null,
            .namelen = 0,
            .iov = &self.send_iovecs,
            .iovlen = 2,
            .control = &self.send_cmsg,
            .controllen = if (len > 0) cmsg_len else 0,
            .flags = 0,
        };

        self.send_c = .{
            .op = .{
                .sendmsg = .{
                    .fd = self.socket_fd,
                    .msghdr = &self.send_msghdr,
                },
            },
            .userdata = self,
            .callback = send_cb,
        };
        self.loop.add(&self.send_c);
    }
    fn send_cb(ud: ?*anyopaque, l: *xev.Loop, c: *xev.Completion, r: xev.Result) xev.CallbackAction {
        _ = l;
        _ = c;
        const connection = @as(*Connection, @ptrCast(@alignCast(ud.?)));
        const ret = r.sendmsg catch unreachable;
        connection.out.count -= ret;

        if (connection.can_send()) {
            std.log.info("resending", .{});
            connection.send();
        }
        return .disarm;
    }
};

pub const Client = struct {
    wl_display: *wl.Display,
    objects: std.ArrayList(?Proxy),
    unused_oids: std.ArrayList(u32),
    connection: *Connection,
    allocator: std.mem.Allocator,
    // reusable_oids: std.

    pub const Event = wl.Display.Event;

    pub fn next_id(self: *const Client) u32 {
        for (self.objects.items, 0..) |*obj, id| {
            if (id == 0) continue;
            if (obj.* == null) return @intCast(id);
        }
        unreachable;
    }

    pub fn next_object(self: *const Client) *?Proxy {
        return &self.objects.items[self.next_id()];
    }

    pub fn connect(allocator: std.mem.Allocator) !*Client {
        var loop = try xev.IO_Uring.Loop.init(.{});
        errdefer loop.deinit();

        var self = try allocator.create(Client);
        self.* = .{
            .wl_display = undefined,
            .objects = try std.ArrayList(?Proxy).initCapacity(allocator, 1000),
            .unused_oids = std.ArrayList(u32).init(allocator),
            .connection = undefined,
            .allocator = allocator,
        };

        try self.objects.appendNTimes(null, 1000);

        const next = self.next_object();
        next.* = Proxy{ .client = self, .interface = &wl.Display.interface, .id = 1 };
        self.wl_display = @ptrCast(next);

        const xdg_runtime_dir = std.os.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
        const wl_display_name = std.os.getenv("WAYLAND_DISPLAY") orelse "wayland-0";

        const fd = try std.os.socket(linux.AF.UNIX, linux.SOCK.STREAM, 0);
        var buf: [std.os.PATH_MAX]u8 = undefined;
        const a = try std.fmt.bufPrint(&buf, "{s}/{s}", .{ xdg_runtime_dir, wl_display_name });

        var addr = try std.net.Address.initUnix(a);
        try std.os.connect(fd, &addr.any, addr.getOsSockLen());

        const connection = try allocator.create(Connection);
        connection.* = .{
            .socket_fd = fd,
            .in = .{},
            .out = .{},
            .fd_in = .{},
            .fd_out = .{},
            .loop = loop,
            .client = self,
        };

        self.connection = connection;

        self.set_listener(?*anyopaque, displayListener, null);

        return self;
    }

    const Header = packed struct {
        id: u32,
        opcode: u16,
        size: u16,
    };

    pub fn consumeEvents(self: *const Client) !void {
        while (true) {
            const pre_wrap = self.connection.in.preWrapSlice();
            var header: Header = undefined;
            _ = self.connection.in.copy(std.mem.asBytes(&header));

            if (self.connection.in.count < header.size) break;
            const proxy = &self.objects.items[header.id].?;

            var data = pre_wrap;
            if (data.len < header.size) {
                data = try self.allocator.alloc(u8, header.size);
                _ = self.connection.in.copy(data);
            }

            proxy.unmarshal_event(data[8..header.size], header.opcode);

            if (pre_wrap.len < header.size) self.allocator.free(data);

            self.connection.in.consume(header.size);
            if (self.connection.in.count < 8) break;
        }
    }
    pub fn recvEvents(self: *const Client) !void {
        self.connection.send();
        self.connection.recv();
        try self.connection.loop.run(.until_done);
    }

    pub fn deinit(self: *Client) void {
        std.os.close(self.connection.socket_fd);
        self.objects.deinit();
        self.unused_oids.deinit();
        self.allocator.destroy(self.connection);
        self.allocator.destroy(self);
    }

    pub inline fn get_registry(self: *Client) !*wl.Registry {
        return self.wl_display.get_registry();
    }

    pub inline fn sync(self: *const Client) !*wl.Callback {
        return self.wl_display.sync();
    }

    pub inline fn set_listener(
        self: *Client,
        comptime T: type,
        comptime _listener: fn (display: *Client, event: Event, data: T) void,
        _data: T,
    ) void {
        const w = struct {
            fn l(display: *wl.Display, event: Event, data: T) void {
                const u: *Client = display.proxy.client;
                _listener(u, event, data);
            }
        };
        return self.wl_display.set_listener(T, w.l, _data);
    }
    pub fn roundtrip(self: *const Client) !void {
        const w = struct {
            fn cbListener(cb: *wl.Callback, _: wl.Callback.Event, done: *bool) void {
                _ = cb;
                done.* = true;
                // Todo: cb.destroy()
                // std.log.info("event: {}", .{event});
            }
        };
        const callblack = try self.sync();
        var done: bool = false;
        callblack.set_listener(*bool, w.cbListener, &done);
        self.connection.is_running = false;
        defer self.connection.is_running = true;
        self.connection.send();
        try self.connection.loop.run(.until_done);
        while (!done) {
            self.connection.recv();
            try self.connection.loop.run(.once);
        }
    }
};

fn displayListener(display: *Client, event: wl.Display.Event, _: ?*anyopaque) void {
    switch (event) {
        .@"error" => |e| {
            std.log.err("Wayland error {}: {s}", .{ e.code, e.message });
        },
        .delete_id => |del| {
            std.debug.assert(display.objects.items[del.id] != null);
            std.log.info("deleted id: {}", .{del.id});
            display.objects.items[del.id] = null;
        },
    }
}
