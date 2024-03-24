const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.wl;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const client = try wayland.Client.connect(allocator);
    const registry = client.request(client.wl_display, .get_registry, {});
    client.set_listener(registry, ?*anyopaque, listener, null);
    try client.roundtrip();
    try client.roundtrip();
    client.deinit();
}

fn listener(client: *wayland.Client, registry: wl.Registry, event: wl.Registry.Event, _: ?*anyopaque) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, "wl_seat") == .eq) {
                std.debug.print("global: {}\n", .{global});
                const seat = client.bind(registry, global.name, wl.Seat, global.version);
                client.set_listener(seat, ?*anyopaque, seatListener, null);
            }
        },
        .global_remove => {},
    }
}

fn seatListener(_: *wayland.Client, _: wl.Seat, event: wl.Seat.Event, _: ?*anyopaque) void {
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
