const std = @import("std");
const linux = std.os.linux;
const Proxy = @import("proxy.zig").Proxy;
const ObjectAttrs = @import("proxy.zig").ObjectAttrs;
const Argument = @import("argument.zig").Argument;
const RingBuffer = @import("ring_buffer.zig").RingBuffer;
const wl = @import("generated/wl.zig");
const Cmsghdr = @import("cmsghdr.zig").Cmsghdr;

pub const Connection = struct {
    socket_fd: linux.socket_t,
    in: RingBuffer(1024) = .{},
    out: RingBuffer(1024) = .{},
    fd_in: RingBuffer(512) = .{},
    fd_out: RingBuffer(512) = .{},
    client: *Client,

    send_cmsg: Cmsghdr([5]linux.fd_t) = undefined,

    is_running: bool = true,

    fn recvInner(self: *Connection) !void {
        var iovecs = self.in.get_write_iovecs();

        var msg: linux.msghdr = .{
            .name = null,
            .namelen = 0,
            .iov = &iovecs,
            .iovlen = iovecs.len,
            .control = null,
            .controllen = 0,
            .flags = 0,
        };

        const rc = linux.recvmsg(self.socket_fd, &msg, 0);
        if (linux.errno(rc) != .SUCCESS) return error.RecvFailed;
        const bytes_received = rc;

        self.in.count += bytes_received;

        try self.client.consumeEvents();
    }

    fn sendInner(self: *Connection) !void {
        var iovecs = self.out.get_read_iovecs();

        // Prepare control message for file descriptors
        self.send_cmsg = Cmsghdr([5]linux.fd_t).init(.{
            .level = linux.SOL.SOCKET,
            .type = 1, //SCM_RIGHTS
        });
        const fd_count = self.fd_out.copy(@ptrCast(self.send_cmsg.dataPtr()));
        self.fd_out.consume(fd_count);
        const cmsg_len: usize = @intCast(@TypeOf(self.send_cmsg).data_offset + fd_count);
        self.send_cmsg.headerPtr().len = @intCast(cmsg_len);

        var msg: linux.msghdr_const = .{
            .name = null,
            .namelen = 0,
            .iov = @ptrCast(&iovecs),
            .iovlen = iovecs.len,
            .control = if (fd_count > 0) @ptrCast(&self.send_cmsg) else null,
            .controllen = if (fd_count > 0) cmsg_len else 0,
            .flags = 0,
        };

        const rc = linux.sendmsg(self.socket_fd, &msg, 0);
        if (linux.errno(rc) != .SUCCESS) return error.SendFailed;
        const bytes_sent = rc;

        self.out.count -= bytes_sent;
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

    pub fn connect(allocator: std.mem.Allocator, environ_map: *std.process.Environ.Map) !*Client {
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

        const xdg_runtime_dir = environ_map.get("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
        const wl_display_name = environ_map.get("WAYLAND_DISPLAY") orelse "wayland-0";

        const socket_rc = linux.socket(linux.AF.UNIX, linux.SOCK.STREAM, 0);
        if (linux.errno(socket_rc) != .SUCCESS) return error.SocketCreateFailed;
        const fd: linux.fd_t = @intCast(socket_rc);

        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const socket_path = try std.fmt.bufPrint(&buf, "{s}/{s}\x00", .{ xdg_runtime_dir, wl_display_name });

        var addr: linux.sockaddr.un = undefined;
        addr.family = linux.AF.UNIX;
        @memcpy(addr.path[0..socket_path.len], socket_path);

        const connect_rc = linux.connect(fd, @ptrCast(&addr), @sizeOf(@TypeOf(addr)));
        if (linux.errno(connect_rc) != .SUCCESS) return error.ConnectFailed;

        const connection = try allocator.create(Connection);
        connection.* = .{
            .socket_fd = fd,
            .in = .{},
            .out = .{},
            .fd_in = .{},
            .fd_out = .{},
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
            _ = self.connection.in.copy(@ptrCast(&header));

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
        const conn = self.connection;

        // Send any pending messages
        if (conn.out.count > 0 or conn.fd_out.count > 0) {
            try conn.sendInner();
        }

        while (conn.is_running) {
            try conn.recvInner();

            // Send any responses generated by event handlers
            if (conn.out.count > 0 or conn.fd_out.count > 0) {
                try conn.sendInner();
            }
        }
    }

    pub fn deinit(self: *Client) void {
        _ = linux.close(self.connection.socket_fd);
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
        const conn = self.connection;
        const was_running = conn.is_running;
        conn.is_running = false;
        defer conn.is_running = was_running;

        // Send the sync request
        try conn.sendInner();

        while (!done) {
            try conn.recvInner();
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
        value: @FieldType(ObjectAttrs, @tagName(item)),
    ) void {
        self.objects.items(item)[@intFromEnum(idx)] = value;
    }

    pub fn request(
        self: *Client,
        idx: anytype,
        comptime tag: std.meta.Tag(@TypeOf(idx).Request),
        payload: @FieldType(@TypeOf(idx).Request, @tagName(tag)),
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
        const v = @min(T.interface.version, _version);
        var _args = [_]Argument{
            .{ .uint = _name },
            .{ .string = T.interface.name },
            .{ .uint = v },
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
            // std.log.info("del id {}", .{id});
            std.debug.assert(client.objects.items(.is_free)[id] == false);
            client.objects.items(.is_free)[id] = true;
        },
    }
}
