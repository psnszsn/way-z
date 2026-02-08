pub const std_options = std.Options{
    .log_level = .info,
};

const App = struct {
    shm: ?wl.Shm,
    compositor: ?wl.Compositor,
    wm_base: ?xdg.WmBase,
    fractional_scale_manager: ?wp.FractionalScaleManagerV1 = null,
    viewporter: ?wp.Viewporter = null,
    running: bool = true,
};

const SurfaceCtx = struct {
    ctx: *App,
    wl_surface: wl.Surface,
    xdg_surface: xdg.Surface,
    xdg_toplevel: xdg.Toplevel,
    viewport: ?wp.Viewport = null,
    fractional_scale: ?wp.FractionalScaleV1 = null,
    width: u31,
    height: u31,
    scale_120: u32 = 120,
    offset: f32,
    last_frame: u32,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const client = try wayland.Client.connect(allocator, init.environ_map);
    const registry = client.request(client.wl_display, .get_registry, .{});

    var context = App{
        .shm = null,
        .compositor = null,
        .wm_base = null,
    };

    client.set_listener(registry, *App, registryListener, &context);
    try client.roundtrip();

    const compositor = context.compositor orelse return error.NoWlCompositor;
    const wm_base = context.wm_base orelse return error.NoXdgWmBase;

    var surface: SurfaceCtx = b: {
        const wl_surface = client.request(compositor, .create_surface, .{});
        const xdg_surface = client.request(wm_base, .get_xdg_surface, .{ .surface = wl_surface });
        const xdg_toplevel = client.request(xdg_surface, .get_toplevel, .{});

        client.request(xdg_toplevel, .set_min_size, .{ .width = 500, .height = 200 });
        client.request(xdg_toplevel, .set_title, .{ .title = "Demo" });

        client.request(wl_surface, .commit, {});

        var s: SurfaceCtx = .{
            .xdg_surface = xdg_surface,
            .xdg_toplevel = xdg_toplevel,
            .wl_surface = wl_surface,
            .width = 100,
            .height = 100,
            .last_frame = 0,
            .offset = 0,
            .ctx = &context,
        };

        if (context.fractional_scale_manager != null and context.viewporter != null) {
            s.fractional_scale = client.request(context.fractional_scale_manager.?, .get_fractional_scale, .{
                .surface = wl_surface,
            });
            s.viewport = client.request(context.viewporter.?, .get_viewport, .{
                .surface = wl_surface,
            });
        }
        break :b s;
    };
    if (surface.fractional_scale) |fs| {
        client.set_listener(fs, *SurfaceCtx, fractional_scale_listener, &surface);
    }
    defer client.request(surface.wl_surface, .destroy, {});
    defer client.request(surface.xdg_toplevel, .destroy, {});
    defer client.request(surface.xdg_surface, .destroy, {});
    defer if (surface.fractional_scale) |fs| client.request(fs, .destroy, {});
    defer if (surface.viewport) |vp| client.request(vp, .destroy, {});

    client.set_listener(surface.xdg_surface, *SurfaceCtx, xdg_surface_listener, &surface);
    client.set_listener(surface.xdg_toplevel, *SurfaceCtx, xdg_toplevel_listener, &surface);
    try client.roundtrip();

    const buf = try Buffer.get(client, surface.ctx.shm.?, surface.width, surface.height);
    client.request(surface.wl_surface, .attach, .{ .buffer = buf.wl_buffer, .x = 0, .y = 0 });

    client.request(surface.wl_surface, .commit, {});
    try client.roundtrip();

    const frame_cb = client.request(surface.wl_surface, .frame, .{});
    client.set_listener(frame_cb, *SurfaceCtx, frame_listener, &surface);
    client.request(surface.wl_surface, .commit, {});

    try client.recvEvents();
}

fn registryListener(client: *wayland.Client, registry: wl.Registry, event: wl.Registry.Event, context: *App) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = client.bind(registry, global.name, wl.Compositor, 1);
            } else if (mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                context.shm = client.bind(registry, global.name, wl.Shm, 1);
            } else if (mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                context.wm_base = client.bind(registry, global.name, xdg.WmBase, 1);
            } else if (mem.orderZ(u8, global.interface, wp.FractionalScaleManagerV1.interface.name) == .eq) {
                context.fractional_scale_manager = client.bind(registry, global.name, wp.FractionalScaleManagerV1, 1);
            } else if (mem.orderZ(u8, global.interface, wp.Viewporter.interface.name) == .eq) {
                context.viewporter = client.bind(registry, global.name, wp.Viewporter, 1);
            }
        },
        .global_remove => {},
    }
}

const palette = [_]u32{ 0xff1a1c2c, 0xff5d275d, 0xffb13e53, 0xffef7d57, 0xffffcd75, 0xffa7f070, 0xff38b764, 0xff257179, 0xff29366f, 0xff3b5dc9, 0xff41a6f6, 0xff73eff7, 0xfff4f4f4, 0xff94b0c2, 0xff566c86, 0xff333c57 };

fn draw(buf: []align(4) u8, width: u32, height: u32, _offset: f32) void {
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

fn draw2(buf: []align(4) u8, width: u32, height: u32, _offset: f32) void {
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

fn fractional_scale_listener(_: *wayland.Client, _: wp.FractionalScaleV1, event: wp.FractionalScaleV1.Event, surf: *SurfaceCtx) void {
    switch (event) {
        .preferred_scale => |data| {
            surf.scale_120 = data.scale;
        },
    }
}

fn xdg_surface_listener(client: *wayland.Client, xdg_surface: xdg.Surface, event: xdg.Surface.Event, surf: *SurfaceCtx) void {
    _ = surf;
    switch (event) {
        .configure => |configure| {
            client.request(xdg_surface, .ack_configure, .{ .serial = configure.serial });
        },
    }
}

fn xdg_toplevel_listener(_: *wayland.Client, _: xdg.Toplevel, event: xdg.Toplevel.Event, surf: *SurfaceCtx) void {
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

fn frame_listener(client: *wayland.Client, cb: wl.Callback, event: wl.Callback.Event, surf: *SurfaceCtx) void {
    _ = cb;
    switch (event) {
        .done => |done| {
            const time = done.callback_data;
            defer surf.last_frame = time;

            const frame_cb = client.request(surf.wl_surface, .frame, .{});

            client.set_listener(frame_cb, *SurfaceCtx, frame_listener, surf);

            if (surf.last_frame != 0) {
                const elapsed: f32 = @floatFromInt(time - surf.last_frame);
                surf.offset += elapsed / 1000.0 * 24;
            }

            defer client.request(surf.wl_surface, .commit, {});

            const pixel_w: u31 = @intCast((@as(u32, surf.width) * surf.scale_120 + 60) / 120);
            const pixel_h: u31 = @intCast((@as(u32, surf.height) * surf.scale_120 + 60) / 120);
            const buf = Buffer.get(client, surf.ctx.shm.?, pixel_w, pixel_h) catch return;
            draw(buf.mem(), pixel_w, pixel_h, surf.offset);
            client.request(surf.wl_surface, .attach, .{ .buffer = buf.wl_buffer, .x = 0, .y = 0 });
            if (surf.viewport) |vp| {
                client.request(vp, .set_destination, .{
                    .width = @intCast(surf.width),
                    .height = @intCast(surf.height),
                });
            }
            client.request(surf.wl_surface, .damage, .{
                .x = 0,
                .y = 0,
                .width = std.math.maxInt(i32),
                .height = std.math.maxInt(i32),
            });
        },
    }
}

const std = @import("std");
const mem = std.mem;

const wayland = @import("wayland");
const wl = wayland.wl;
const wp = wayland.wp;
const xdg = wayland.xdg;

const Buffer = wayland.shm.Buffer;
