const std = @import("std");
const linux = std.os.linux;
const Proxy = @import("proxy.zig").Proxy;
const IO = @import("io_async.zig").IO;
const Registry = @import("main.zig").Registry;
const RingBuffer = @import("ring_buffer.zig").RingBuffer;
const Argument = @import("argument.zig").Argument;

pub const Connection = struct {
    socket_fd: std.os.socket_t,
    in: RingBuffer(512),
    out: RingBuffer(512),
    io: *IO,
    pub fn recv(self: *Connection) !usize {
        var iovecs = self.in.get_write_iovecs();
        var msg = std.os.msghdr{
            .name = null,
            .namelen = 0,
            .iov = &iovecs,
            .iovlen = 2,
            .control = null,
            .controllen = 0,
            .flags = 0,
        };

        const ret = try self.io.recvmsg(self.socket_fd, &msg);
        self.in.count += ret;

        return ret;
    }

    pub fn send(self: *Connection) !usize {
        var iovecs = self.out.get_read_iovecs();
        var msg = std.os.msghdr_const{
            .name = null,
            .namelen = 0,
            .iov = &iovecs,
            .iovlen = 2,
            .control = null,
            .controllen = 0,
            .flags = 0,
        };

        const ret = try self.io.sendmsg(self.socket_fd, &msg);
        self.out.count -= ret;

        return ret;
    }
};

pub const Display = struct {
    proxy: Proxy,
    objects: std.ArrayList(?*Proxy),
    unused_oids: std.ArrayList(u32),
    connection: *Connection,
    allocator: std.mem.Allocator,
    // reusable_oids: std.

    pub const Event = union(enum) {
        @"error": struct {
            object_id: ?*anyopaque,
            code: u32,
            message: [*:0]const u8,
        },
        delete_id: struct {
            id: u32,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub fn connect(allocator: std.mem.Allocator, io: *IO) !*Display {
        var self = try allocator.create(Display);
        self.* = .{
            .proxy = .{ .display = self, .event_args = &Display.event_signatures },
            .objects = std.ArrayList(?*Proxy).init(allocator),
            .unused_oids = std.ArrayList(u32).init(allocator),
            .connection = undefined,
            .allocator = allocator,
        };
        try self.objects.append(null);
        try self.objects.append(&self.proxy);
        self.proxy.id = @as(u32, @intCast(self.objects.items.len - 1));

        const xdg_runtime_dir = std.os.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
        const wl_display = std.os.getenv("WAYLAND_DISPLAY") orelse "wayland-0";

        const fd = try std.os.socket(linux.AF.UNIX, linux.SOCK.STREAM, 0);
        var buf: [std.os.PATH_MAX]u8 = undefined;
        const a = try std.fmt.bufPrint(&buf, "{s}/{s}", .{ xdg_runtime_dir, wl_display });

        var addr = try std.net.Address.initUnix(a);
        try io.connect(fd, &addr.any, addr.getOsSockLen());

        var connection = try allocator.create(Connection);
        connection.* = .{
            .socket_fd = fd,
            .io = io,
            .in = .{},
            .out = .{},
        };

        self.connection = connection;

        return self;
    }

    const Header = packed struct {
        id: u32,
        opcode: u16,
        size: u16,
    };

    pub fn recvEvents(self: *Display) !void {
        var total = try self.connection.recv();
        // var rem = self.connection.in.count;
        if (total == 0) {
            return error.BrokenPipe;
        }
        while (true) {
            var pre_wrap = self.connection.in.preWrapSlice();
            var header: Header = undefined;
            self.connection.in.copy(std.mem.asBytes(&header));

            if (self.connection.in.count < header.size) break;
            const proxy = self.objects.items[header.id].?;

            var data = pre_wrap;
            if (data.len < header.size) {
                data = try self.allocator.alloc(u8, header.size);
                self.connection.in.copy(data);
            }

            proxy.unmarshal_event(data[8..header.size], header.opcode);

            if (pre_wrap.len < header.size) self.allocator.free(data);

            self.connection.in.consume(header.size);
            if (self.connection.in.count < 8) break;
        }
    }
    pub fn deinit(self: *Display) void {
        self.connection.io.close(self.connection.socket_fd) catch unreachable;
        self.objects.deinit();
        self.unused_oids.deinit();
        self.allocator.destroy(self.connection);
        self.allocator.destroy(self);
    }

    pub fn getRegistry(self: *Display) !*Registry {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Registry, 1, &_args);
    }

    pub fn sync(self: *Display) !*Callback {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Callback, 0, &_args);
    }
};

pub const Callback = struct {
    proxy: Proxy,

    pub const Event = union(enum) {
        done: struct {
            callback_data: u32,
        },
    };

    pub const event_signatures = Proxy.genEventArgs(Event);
};
