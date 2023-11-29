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
    display.setListener(?*anyopaque, displayListener, null);
    registry.setListener(?*anyopaque, listener, null);
    try display.roundtrip();
    try display.roundtrip();
}

fn listener(registry: *wl.Registry, event: wl.Registry.Event, _: ?*anyopaque) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, "wl_seat") == .eq) {
                std.debug.print("global: {}\n", .{global});
                const seat = registry.bind(global.name, wl.Seat, global.version) catch return;
                seat.setListener(?*anyopaque, seatListener, null);
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

fn displayListener(_: *wayland.Display, event: wl.Display.Event, _: ?*anyopaque) void {
    switch (event) {
        .@"error" => |e| {
            std.debug.print("error {} {s}\n", .{ e.code, e.message });
        },
        .delete_id => |id| {
            std.debug.print("delede_id {}\n", .{id});
        },
    }
}
