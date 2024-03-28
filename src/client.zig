const std = @import("std");
const linux = std.os.linux;
const Proxy = @import("proxy.zig").Proxy;
const ObjectAttrs = @import("proxy.zig").ObjectAttrs;
const Argument = @import("argument.zig").Argument;
const xev = @import("xev");
const RingBuffer = @import("ring_buffer.zig").RingBuffer;
const wl = @import("generated/wl.zig");
const Cmsghdr = @import("cmsghdr.zig").Cmsghdr;

pub const Connection = struct {
    socket_fd: std.posix.socket_t,
    in: RingBuffer(1024) = .{},
    out: RingBuffer(1024) = .{},
    fd_in: RingBuffer(512) = .{},
    fd_out: RingBuffer(512) = .{},
    client: *Client,
    loop: xev.IO_Uring.Loop,

    recv_c: xev.Completion = .{},
    recv_cancel_c: xev.Completion = .{},
    recv_iovecs: [2]std.posix.iovec = undefined,
    recv_msghdr: std.posix.msghdr = undefined,

    send_c: xev.Completion = .{},
    send_iovecs: [2]std.posix.iovec_const = undefined,
    send_msghdr: std.posix.msghdr_const = undefined,
    send_cmsg: Cmsghdr([5]std.posix.fd_t) = undefined,

    is_running: bool = true,

    pub fn recv(self: *Connection) void {
        self.recv_iovecs = self.in.get_write_iovecs();
        self.recv_msghdr = std.posix.msghdr{
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
            if (connection.can_send()) connection.send();
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
        self.send_iovecs = self.out.get_read_iovecs();
        self.send_cmsg = Cmsghdr([5]std.posix.fd_t).init(.{
            .level = std.posix.SOL.SOCKET,
            .type = 1, //SCM_RIGHTS
        });
        const len = self.fd_out.copy(std.mem.asBytes(self.send_cmsg.dataPtr()));
        self.fd_out.consume(len);
        const cmsg_len: u32 = @intCast(@TypeOf(self.send_cmsg).data_offset + len);
        self.send_cmsg.headerPtr().len = cmsg_len;
        // std.debug.print("fd len {}\n", .{len});

        self.send_msghdr = std.posix.msghdr_const{
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
    fn send_cb(ud: ?*anyopaque, _: *xev.Loop, _: *xev.Completion, r: xev.Result) xev.CallbackAction {
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
    wl_display: wl.Display,
    // objects: std.ArrayListUnmanaged(?Proxy) = .{},
    objects: std.MultiArrayList(ObjectAttrs) = .{},
    unused_oids: std.ArrayListUnmanaged(u32) = .{},
    connection: *Connection,
    allocator: std.mem.Allocator,

    pub const Event = wl.Display.Event;

    pub fn next_id(self: *Client) u32 {
        for (self.objects.items(.is_free), 0..) |is_free, id| {
            if (is_free) return @intCast(id);
        }
        const next = self.objects.addOneAssumeCapacity();
        return @intCast(next);
    }

    pub fn next_object(self: *Client) Proxy {
        const id = self.next_id();
        return .{
            .client = self,
            .id = id,
        };
    }

    pub fn connect(allocator: std.mem.Allocator) !*Client {
        var loop = try xev.IO_Uring.Loop.init(.{});
        errdefer loop.deinit();

        var self = try allocator.create(Client);
        self.* = .{
            .wl_display = undefined,
            .connection = undefined,
            .allocator = allocator,
        };

        try self.objects.ensureTotalCapacity(allocator, 1000);

        _ = self.next_id(); //discard

        const idx = self.next_id();

        self.objects.set(idx, .{ .interface = &wl.Display.interface });

        self.wl_display = @enumFromInt(idx);

        const xdg_runtime_dir = std.posix.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
        const wl_display_name = std.posix.getenv("WAYLAND_DISPLAY") orelse "wayland-0";

        const fd = try std.posix.socket(linux.AF.UNIX, linux.SOCK.STREAM, 0);
        var buf: [std.posix.PATH_MAX]u8 = undefined;
        const a = try std.fmt.bufPrint(&buf, "{s}/{s}", .{ xdg_runtime_dir, wl_display_name });

        var addr = try std.net.Address.initUnix(a);
        try std.posix.connect(fd, &addr.any, addr.getOsSockLen());

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

        self.set_listener(self.wl_display, ?*anyopaque, displayListener, null);

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
            const proxy = Proxy{
                .id = header.id,
                .client = @constCast(self),
            };

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
        std.posix.close(self.connection.socket_fd);
        self.objects.deinit(self.allocator);
        self.unused_oids.deinit(self.allocator);
        self.allocator.destroy(self.connection);
        self.allocator.destroy(self);
    }

    pub fn roundtrip(self: *Client) !void {
        const w = struct {
            fn cbListener(_: *Client, _: wl.Callback, _: wl.Callback.Event, done: *bool) void {
                done.* = true;
            }
        };
        const callblack = self.request(self.wl_display, .sync, .{});
        var done: bool = false;
        self.set_listener(callblack, *bool, w.cbListener, &done);
        self.connection.is_running = false;
        defer self.connection.is_running = true;
        self.connection.send();
        try self.connection.loop.run(.until_done);
        while (!done) {
            self.connection.recv();
            try self.connection.loop.run(.once);
        }
    }

    pub fn set_listener(
        self: *Client,
        object: anytype,
        comptime T: type,
        comptime _listener: *const fn (*Client, @TypeOf(object), @TypeOf(object).Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(client: *Client, idx: u32, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = @TypeOf(object).Event.from_args(opcode, args);
                @call(.always_inline, _listener, .{
                    client,
                    @as(@TypeOf(object), @enumFromInt(idx)),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.set(object, .listener, w.inner);
        self.set(object, .listener_data, _data);
    }

    pub fn get(
        self: *Client,
        idx: anytype,
        comptime item: std.meta.FieldEnum(ObjectAttrs),
    ) std.meta.FieldType(ObjectAttrs, item) {
        return self.objects.items(item)[@intFromEnum(idx)];
    }

    pub fn set(
        self: *Client,
        idx: anytype,
        comptime item: std.meta.FieldEnum(ObjectAttrs),
        value: std.meta.FieldType(ObjectAttrs, item),
    ) void {
        self.objects.items(item)[@intFromEnum(idx)] = value;
    }

    const prx = @import("proxy.zig");

    pub fn request(
        self: *Client,
        idx: anytype,
        comptime tag: std.meta.Tag(@TypeOf(idx).Request),
        payload: std.meta.TagPayload(@TypeOf(idx).Request, tag),
    ) @TypeOf(idx).Request.ReturnType(tag) {
        const T = @TypeOf(idx);
        var _args = @import("proxy.zig").request_to_args(T.Request, tag, payload);
        // std.log.info("{} {s} {} args: {any}", .{ idx, @tagName(tag), @intFromEnum(tag), _args });

        const proxy = Proxy{ .client = self, .id = @intFromEnum(idx) };

        const RT = T.Request.ReturnType(tag);
        if (RT == void) {
            return proxy.marshal_request(@intFromEnum(tag), &_args) catch unreachable;
        } else {
            return proxy.marshal_request_constructor(RT, @intFromEnum(tag), &_args) catch @panic("buffer full");
        }
    }
    pub fn bind(client: *Client, idx: wl.Registry, _name: u32, comptime T: type, _version: u32) T {
        var _args = [_]Argument{
            .{ .uint = _name },
            .{ .string = T.interface.name },
            .{ .uint = _version },
            .{ .new_id = 0 },
        };
        const proxy = Proxy{ .client = client, .id = @intFromEnum(idx) };
        return proxy.marshal_request_constructor(T, 0, &_args) catch @panic("buffer full");
    }
};

fn displayListener(client: *Client, _: wl.Display, event: wl.Display.Event, _: ?*anyopaque) void {
    switch (event) {
        .@"error" => |e| {
            std.log.err("Wayland error {}: {s}", .{ e.code, e.message });
        },
        .delete_id => |del| {
            const id = del.id;
            std.log.info("del id {}", .{id});
            std.debug.assert(client.objects.items(.is_free)[id] == false);
            client.objects.items(.is_free)[id] = true;
        },
    }
}
