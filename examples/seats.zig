const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.wl;


pub const main = wayland.my_main;

pub fn async_main(io: *wayland.IO) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const client = try wayland.Client.connect(allocator, io);
    const registry = try client.get_registry();
    registry.set_listener(?*anyopaque, listener, null);
    try client.roundtrip();
    try client.roundtrip();
    client.deinit();
}

fn listener(registry: *wl.Registry, event: wl.Registry.Event, _: ?*anyopaque) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, "wl_seat") == .eq) {
                std.debug.print("global: {}\n", .{global});
                const seat = registry.bind(global.name, wl.Seat, global.version) catch return;
                seat.set_listener(?*anyopaque, seatListener, null);
            }
        },
        .global_remove => {},
    }
}

fn seatListener(_: *wl.Seat, event: wl.Seat.Event, _: ?*anyopaque) void {
    switch (event) {
        .capabilities => |data| {
            std.debug.print("Seat capabilities\n  Pointer {}\n  Keyboard {}\n  Touch {}\n", .{
                data.capabilities.pointer,
                data.capabilities.keyboard,
                data.capabilities.touch,
            });
        },
        .name => |name| {
            std.debug.print("seat name: {s}\n", .{name.name});
        },
    }
}
