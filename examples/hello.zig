const std = @import("std");
const mem = std.mem;
const os = std.os;

const wayland = @import("wayland");
const wl = wayland.wl;
const xdg = wayland.xdg;

const Buffer = wayland.shm.Buffer;

pub const std_options = std.Options{
    .log_level = .info,
};

const App = struct {
    shm: ?*wl.Shm,
    compositor: ?*wl.Compositor,
    wm_base: ?*xdg.WmBase,
    running: bool = true,
};

const SurfaceCtx = struct {
    ctx: *App,
    wl_surface: *wl.Surface,
    xdg_surface: *xdg.Surface,
    xdg_toplevel: *xdg.Toplevel,
    width: u32,
    height: u32,
    offset: f32,
    last_frame: u32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const client = try wayland.Client.connect(allocator);
    const registry = client.get_registry();

    var context = App{
        .shm = null,
        .compositor = null,
        .wm_base = null,
    };

    registry.set_listener(*App, registryListener, &context);
    try client.roundtrip();

    const shm = context.shm orelse return error.NoWlShm;
    _ = shm;
    const compositor = context.compositor orelse return error.NoWlCompositor;
    const wm_base = context.wm_base orelse return error.NoXdgWmBase;

    var surface: SurfaceCtx = .{
        .xdg_surface = undefined,
        .xdg_toplevel = undefined,
        .wl_surface = undefined,
        .width = 100,
        .height = 100,
        .last_frame = 0,
        .offset = 0,
        .ctx = &context,
    };

    surface.wl_surface = compositor.create_surface();
    defer surface.wl_surface.destroy();
    surface.xdg_surface = wm_base.get_xdg_surface(surface.wl_surface);
    defer surface.xdg_surface.destroy();
    surface.xdg_toplevel = surface.xdg_surface.get_toplevel();
    defer surface.xdg_toplevel.destroy();

    surface.xdg_surface.set_listener(*SurfaceCtx, xdgSurfaceListener, &surface);
    surface.xdg_toplevel.set_listener(*SurfaceCtx, xdgToplevelListener, &surface);
    surface.xdg_toplevel.set_min_size(500, 200);
    surface.xdg_toplevel.set_title("Demo");
    surface.wl_surface.commit();
    try client.roundtrip();

    const buf = try Buffer.get(surface.ctx.shm.?, surface.width, surface.height);
    surface.wl_surface.attach(buf.wl_buffer, 0, 0);
    surface.wl_surface.commit();
    try client.roundtrip();

    const frame_cb = surface.wl_surface.frame();
    frame_cb.set_listener(*SurfaceCtx, frameListener, &surface);
    surface.wl_surface.commit();

    try client.recvEvents();
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, context: *App) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = registry.bind(global.name, wl.Compositor, 1);
            } else if (mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                context.shm = registry.bind(global.name, wl.Shm, 1);
            } else if (mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                context.wm_base = registry.bind(global.name, xdg.WmBase, 1);
            }
        },
        .global_remove => {},
    }
}

const palette = [_]u32{ 0xff1a1c2c, 0xff5d275d, 0xffb13e53, 0xffef7d57, 0xffffcd75, 0xffa7f070, 0xff38b764, 0xff257179, 0xff29366f, 0xff3b5dc9, 0xff41a6f6, 0xff73eff7, 0xfff4f4f4, 0xff94b0c2, 0xff566c86, 0xff333c57 };

fn draw(buf: []align(4096) u8, width: u32, height: u32, _offset: f32) void {
    const data_u32: []u32 = std.mem.bytesAsSlice(u32, buf);

    const sin = std.math.sin;
    for (0..height) |y| {
        for (0..width) |x| {
            const x_f: f32, const y_f: f32 = .{ @floatFromInt(x), @floatFromInt(y) };
            const c = sin(x_f / 80) + sin(y_f / 80) + sin(_offset / 80);
            const index: i64 = @intFromFloat(c * 4);
            data_u32[y * width + x] = palette[@abs(index) % 16];
        }
    }
}

fn draw2(buf: []align(4096) u8, width: u32, height: u32, _offset: f32) void {
    const offset_int: u32 = @intFromFloat(_offset);
    const offset = offset_int % 8;
    const data_u32: []u32 = std.mem.bytesAsSlice(u32, buf);
    for (0..height) |y| {
        for (0..width) |x| {
            if (((x + offset) + (y + offset) / 8 * 8) % 16 < 8) {
                // if ((x + y / 8 * 8) % 16 < 8) {
                data_u32[y * width + x] = 0xFF666666;
            } else {
                data_u32[y * width + x] = 0xFFEEEEEE;
            }
        }
    }
}

fn xdgSurfaceListener(xdg_surface: *xdg.Surface, event: xdg.Surface.Event, surf: *SurfaceCtx) void {
    _ = surf;
    switch (event) {
        .configure => |configure| {
            xdg_surface.ack_configure(configure.serial);
        },
    }
}

fn xdgToplevelListener(_: *xdg.Toplevel, event: xdg.Toplevel.Event, surf: *SurfaceCtx) void {
    switch (event) {
        .configure => |configure| {
            std.log.warn("new size {} {}", .{ configure.width, configure.height });
            surf.width = @intCast(configure.width);
            surf.height = @intCast(configure.height);
        },
        .close => {
            surf.ctx.running = false;
        },
        else => {},
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

fn frameListener(cb: *wl.Callback, event: wl.Callback.Event, surf: *SurfaceCtx) void {
    _ = cb;
    switch (event) {
        .done => |done| {
            const time = done.callback_data;
            defer surf.last_frame = time;

            const frame_cb = surf.wl_surface.frame();
            frame_cb.set_listener(*SurfaceCtx, frameListener, surf);

            if (surf.last_frame != 0) {
                const elapsed: f32 = @floatFromInt(time - surf.last_frame);
                surf.offset += elapsed / 1000.0 * 24;
            }

            defer surf.wl_surface.commit();
            const buf = Buffer.get(surf.ctx.shm.?, surf.width, surf.height) catch return;
            draw(buf.pool.mmap, surf.width, surf.height, surf.offset);
            surf.wl_surface.attach(buf.wl_buffer, 0, 0);
            surf.wl_surface.damage(0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
        },
    }
}
