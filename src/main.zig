const std = @import("std");
const testing = std.testing;
const linux = std.os.linux;
const IO = @import("io_async.zig").IO;
const IO_Uring = linux.IO_Uring;
const Argument = @import("argument.zig").Argument;
const Proxy = @import("proxy.zig").Proxy;
const Display = @import("display.zig").Display;

pub fn main() !void {
    std.debug.print("aaa\n", .{});

    var io = IO.init(32, 0) catch unreachable;
    defer io.deinit();
    var frame = async way(&io);
    io.run() catch unreachable;
    _ = frame;
    // nosuspend await frame catch unreachable;

}

pub const Registry = struct {
    pub const interface_name = "wl_registry";
    pub const version = 1;
    proxy: Proxy,

    pub const Event = union(enum) {
        global: struct {
            name: u32,
            interface: [*:0]const u8,
            version: u32,
        },
        global_remove: struct {
            name: u32,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub fn deinit(self: *Registry) void {
        _ = event_signatures;
        self.proxy.deinit();
    }
};


pub fn way(io: *IO) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var display = try Display.connect(allocator, io);
    defer display.deinit();
    var registry = try display.getRegistry();
    defer registry.deinit();
    while (true) {
        try display.recvEvents();
        std.debug.print("count {}\n", .{display.connection.in.count});
        if (display.connection.in.count == 0) break;
    }
    // try display.recvEvents();
}
