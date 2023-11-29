const std = @import("std");
const mem = std.mem;
const os = std.os;

const wayland = @import("wayland");
const wl = wayland.wl;
const xdg = wayland.xdg;

const Context = struct {
    shm: ?*wl.Shm,
    compositor: ?*wl.Compositor,
    wm_base: ?*xdg.WmBase,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    try wayland.run_async(allocator, async_main);
}

// pub fn async_main(io: *wayland.IO) !void {
//     const display = try wayland.Display.connect(allocator, io);
//     const registry = try display.get_registry();
//     display.setListener(?*anyopaque, displayListener, null);
//     registry.setListener(?*anyopaque, listener, null);
//     while (true) {
//         try display.recvEvents();
//         std.debug.print("count {}\n", .{display.connection.in.count});
//     }
// }

pub fn async_main(io: *wayland.IO) !void {
    const display = try wayland.Display.connect(allocator, io);
    const registry = try display.get_registry();

    var context = Context{
        .shm = null,
        .compositor = null,
        .wm_base = null,
    };

    registry.setListener(*Context, registryListener, &context);
    try display.roundtrip();

    const shm = context.shm orelse return error.NoWlShm;
    const compositor = context.compositor orelse return error.NoWlCompositor;
    const wm_base = context.wm_base orelse return error.NoXdgWmBase;

    const buffer = blk: {
        const width = 128;
        const height = 128;
        const stride = width * 4;
        const size = stride * height;

        const fd = try os.memfd_create("hello-zig-wayland", 0);
        try os.ftruncate(fd, size);
        const data = try os.mmap(null, size, os.PROT.READ | os.PROT.WRITE, os.MAP.SHARED, fd, 0);
        @memcpy(data, @embedFile("cat.bgra"));

        const pool = try shm.create_pool(fd, size);
        defer pool.destroy();

        break :blk try pool.create_buffer(0, width, height, stride, wl.Shm.Format.argb8888);
    };
    defer buffer.destroy();

    const surface = try compositor.create_surface();
    defer surface.destroy();
    const xdg_surface = try wm_base.get_xdg_surface(surface);
    defer xdg_surface.destroy();
    const xdg_toplevel = try xdg_surface.get_toplevel();
    defer xdg_toplevel.destroy();

    var running = true;

    xdg_surface.setListener(*wl.Surface, xdgSurfaceListener, surface);
    xdg_toplevel.setListener(*bool, xdgToplevelListener, &running);

    surface.commit();
    try display.roundtrip();

    surface.attach(buffer, 0, 0);
    surface.commit();

    while (running) {
        try display.recvEvents();
    }
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, context: *Context) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.name) == .eq) {
                context.compositor = registry.bind(global.name, wl.Compositor, 1) catch return;
            } else if (mem.orderZ(u8, global.interface, wl.Shm.name) == .eq) {
                context.shm = registry.bind(global.name, wl.Shm, 1) catch return;
            } else if (mem.orderZ(u8, global.interface, xdg.WmBase.name) == .eq) {
                context.wm_base = registry.bind(global.name, xdg.WmBase, 1) catch return;
            }
        },
        .global_remove => {},
    }
}

fn xdgSurfaceListener(xdg_surface: *xdg.Surface, event: xdg.Surface.Event, surface: *wl.Surface) void {
    switch (event) {
        .configure => |configure| {
            xdg_surface.ack_configure(configure.serial);
            surface.commit();
        },
    }
}

fn xdgToplevelListener(_: *xdg.Toplevel, event: xdg.Toplevel.Event, running: *bool) void {
    switch (event) {
        .configure => {},
        .close => running.* = false,
        else => {},
    }
}




fn listener(registry: *wl.Registry, event: wl.Registry.Event, _: ?*anyopaque) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, "wl_seat") == .eq) {
                const seat = registry.bind(global.name, wl.Seat) catch return;
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
