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
    pub fn connect(allocator: std.mem.Allocator, io: *IO) !*Display {
        var self = try allocator.create(Display);
        self.* = .{
            .proxy = .{ .display = self, .event_args = &.{} },
            .objects = std.ArrayList(?*Proxy).init(allocator),
            .unused_oids = std.ArrayList(u32).init(allocator),
            .connection = undefined,
            .allocator = allocator,
        };
        try self.objects.append(null);
        try self.objects.append(&self.proxy);
        self.proxy.id = @as(u32, @intCast(self.objects.items.len - 1));

        const fd = try std.os.socket(linux.AF.UNIX, linux.SOCK.STREAM, 0);
        const a = "/tmp/1000-runtime-dir/wayland-1";
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

    pub fn recvEvents(self: *Display) !void {
        var total = try self.connection.recv();
        // var rem = self.connection.in.count;
        if (total == 0) {
            return error.BrokenPipe;
        }
        while (true) {
            var pre_wrap = self.connection.in.preWrapSlice();
            var header_data = pre_wrap;
            if (header_data.len < 8) {
                header_data = try self.allocator.alloc(u8, 8);
                self.connection.in.copy(header_data);
                defer self.allocator.free(header_data);
            }
            const id: u32 = @bitCast(header_data[0..4].*);
            const opcode: u16 = @bitCast(header_data[4..6].*);
            const size: u16 = @bitCast(header_data[6..8].*);

            if (self.connection.in.count < size) break;
            const proxy = self.objects.items[id].?;

            var data = pre_wrap;
            if (data.len < size) {
                data = try self.allocator.alloc(u8, size);
                self.connection.in.copy(data);
            }

            proxy.unmarshal_event(data[8..size], opcode);

            if (pre_wrap.len < 8) self.allocator.free(header_data);
            if (pre_wrap.len < size) self.allocator.free(data);

            self.connection.in.consume(size);
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
        var registry = try self.allocator.create(Registry);
        registry.* = .{ .proxy = .{ .display = self, .event_args = &Registry.event_signatures } };
        try self.objects.append(&registry.proxy);
        registry.proxy.id = @as(u32, @intCast(self.objects.items.len - 1));

        std.debug.print("asd {any}\n", .{Registry.event_signatures});

        var _args = [_]Argument{
            .{ .new_id = registry.proxy.id },
        };
        try self.proxy.marshal_request(1, &_args);
        // var get_registry = "\x01\x00\x00\x00\x01\x00\x0c\x00\x02\x00\x00\x00";

        // try self.connection.out.pushSlice(get_registry);

        const ret = try self.connection.send();
        std.debug.print("sent {}\n", .{ret});

        return registry;
    }
};
