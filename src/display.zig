const std = @import("std");
const linux = std.os.linux;
const Proxy = @import("proxy.zig").Proxy;
const IO = @import("io_async.zig").IO;
const Registry = @import("main.zig").Registry;
const RingBuffer = @import("ring_buffer.zig").RingBuffer;

pub const Connection = struct {
    socket_fd: std.os.socket_t,
    in: RingBuffer(512),
    io: *IO,
    pub fn recv(self: *Connection) !usize {

        var iovecs = self.in.get_write_iovecs();
        var msg = std.os.msghdr{
            .name = null,
            .namelen = 0,
            .iov = &iovecs,
            .iovlen = 1,
            .control = null,
            .controllen = 0,
            .flags = 0,
        };

        const ret = try self.io.recvmsg(self.socket_fd, &msg);
        self.in.count += ret;

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
        self.proxy.id = @intCast(u32, self.objects.items.len - 1);

        const fd = try std.os.socket(linux.AF.UNIX, linux.SOCK.STREAM, 0);
        const a = "/run/user/1000/wayland-1";
        var addr = try std.net.Address.initUnix(a);
        try io.connect(fd, &addr.any, addr.getOsSockLen());

        var connection = try allocator.create(Connection);
        connection.* = .{
            .socket_fd = fd,
            .io = io,
            .in = .{},
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
            const id = std.mem.readIntNative(u32, header_data[0..4]);
            const opcode = std.mem.readIntNative(u16, header_data[4..6]);
            const size = std.mem.readIntNative(u16, header_data[6..8]);

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
        registry.proxy.id = @intCast(u32, self.objects.items.len - 1);

        // const signature: []const ArgumentType = .{.new_id};
        // const types: []?type = .{Registry};
        std.debug.print("asd {any}\n", .{Registry.event_signatures});

        var get_registry = "\x01\x00\x00\x00\x01\x00\x0c\x00\x02\x00\x00\x00";

        var iovecs = [_]std.os.iovec_const{
            .{ .iov_base = get_registry, .iov_len = get_registry.len },
        };

        var msg = std.os.msghdr_const{
            .name = null,
            .namelen = 0,
            .iov = &iovecs,
            .iovlen = 1,
            .control = null,
            .controllen = 0,
            .flags = 0,
        };

        const ret = try self.connection.io.sendmsg(self.connection.socket_fd, &msg);
        std.debug.print("sent {}\n", .{ret});

        return registry;
    }
};
