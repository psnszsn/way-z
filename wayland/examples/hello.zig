pub const std_options = std.Options{
    .log_level = .info,
};

const App = struct {
    shm: ?wl.Shm,
    compositor: ?wl.Compositor,
    wm_base: ?xdg.WmBase,
};

const SurfaceCtx = struct {
    ctx: *App,
    wl_surface: wl.Surface,
    xdg_surface: xdg.Surface,
    xdg_toplevel: xdg.Toplevel,
    width: u31,
    height: u31,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const client = try wayland.Client.connect(allocator);
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

        client.request(xdg_toplevel, .set_title, .{ .title = "Demo" });

        client.request(wl_surface, .commit, {});

        break :b .{
            .xdg_surface = xdg_surface,
            .xdg_toplevel = xdg_toplevel,
            .wl_surface = wl_surface,
            .width = 100,
            .height = 100,
            .ctx = &context,
        };
    };
    defer client.request(surface.wl_surface, .destroy, {});
    defer client.request(surface.xdg_toplevel, .destroy, {});
    defer client.request(surface.xdg_surface, .destroy, {});

    client.set_listener(surface.xdg_surface, *SurfaceCtx, xdg_surface_listener, &surface);

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
            }
        },
        .global_remove => {},
    }
}

fn draw(buf: []align(4) u8, width: u32, height: u32, _offset: f32) void {
    const offset_int: u32 = @intFromFloat(_offset);
    const offset = offset_int % 8;
    const data_u32: []u32 = std.mem.bytesAsSlice(u32, buf);
    for (0..height) |y| {
        for (0..width) |x| {
            if (((x + offset) + (y + offset) / 8 * 8) % 16 < 8) {
                data_u32[y * width + x] = 0xFF666666;
            } else {
                data_u32[y * width + x] = 0xFFEEEEEE;
            }
        }
    }
}

fn xdg_surface_listener(client: *wayland.Client, xdg_surface: xdg.Surface, event: xdg.Surface.Event, surf: *SurfaceCtx) void {
    switch (event) {
        .configure => |configure| {
            client.request(xdg_surface, .ack_configure, .{ .serial = configure.serial });
            const buf = Buffer.get(client, surf.ctx.shm.?, surf.width, surf.height) catch @panic("TODO");
            draw(buf.mem(), surf.width, surf.height, 0);
            client.request(surf.wl_surface, .attach, .{ .buffer = buf.wl_buffer, .x = 0, .y = 0 });
            client.request(surf.wl_surface, .commit, {});
        },
    }
}

const std = @import("std");
const mem = std.mem;

const wayland = @import("wayland");
const wl = wayland.wl;
const xdg = wayland.xdg;
const Buffer = wayland.shm.Buffer;
