const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.wl;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const client = try wayland.Client.connect(allocator);
    const registry = try client.get_registry();
    var foo: u32 = 42;
    registry.set_listener(*u32, listener, &foo);
    try client.roundtrip();
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
