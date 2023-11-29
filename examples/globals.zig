const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.wl;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
// defer std.debug.assert(!gpa.deinit());
const allocator = gpa.allocator();

pub fn main() !void {
    try wayland.run_async(allocator, async_main);
}

pub fn async_main(io: *wayland.IO) !void {
    const display = try wayland.Display.connect(allocator, io);
    const registry = try display.get_registry();
    var foo: u32 = 42;
    registry.set_listener(*u32, listener, &foo);
    // if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;
    // try display.recvEvents();
    try display.roundtrip();
    // while (true) {
    //     try display.recvEvents();
    //     std.debug.print("count {}\n", .{display.connection.in.count});
    // }
}

fn listener(_: *wl.Registry, event: wl.Registry.Event, data: *u32) void {
    std.debug.print("foo is {}\n", .{data.*});
    switch (event) {
        .global => |e| {
            std.debug.print("global: {s}\n", .{e.interface});
        },
        .global_remove => {},
    }
}
