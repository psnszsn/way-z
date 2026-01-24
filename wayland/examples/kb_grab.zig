//  Grab keyboard events and print them to stdout

pub const std_options = std.Options{
    .log_level = .info,
};

const Globals = struct {
    shm: ?wl.Shm = null,
    compositor: ?wl.Compositor = null,
    wm_base: ?xdg.WmBase = null,
    seat: ?wl.Seat = null,
    keyboard: ?wl.Keyboard = null,
    layer_shell: ?zwlr.LayerShellV1 = null,
    shortcut_inhibit_manager: ?zwp.KeyboardShortcutsInhibitManagerV1 = null,
};

const SurfaceCtx = struct {
    ctx: *Globals,
    wl_surface: wl.Surface,
    layer_surface: wayland.zwlr.LayerSurfaceV1,
    shortcut_inhibitor: zwp.KeyboardShortcutsInhibitorV1,
    width: u31,
    height: u31,
    offset: f32,
    last_frame: u32,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const client = try wayland.Client.connect(allocator, init.environ_map);
    defer client.deinit();
    const registry = client.request(client.wl_display, .get_registry, .{});

    var context = Globals{};

    client.set_listener(registry, *Globals, registryListener, &context);
    try client.roundtrip();

    const shm = context.shm orelse return error.NoWlShm;
    const compositor = context.compositor orelse return error.NoWlCompositor;
    const seat = context.seat orelse return error.NoSeat;
    const shortcut_inhibit_manager = context.shortcut_inhibit_manager orelse return error.NoShortcutInhibitor;

    const surface: SurfaceCtx = b: {
        const wl_surface = client.request(compositor, .create_surface, .{});
        const shortcut_inhibitor = client.request(shortcut_inhibit_manager, .inhibit_shortcuts, .{ .surface = wl_surface, .seat = seat });
        const width = 10;
        const height = 10;

        const layer_surface = client.request(context.layer_shell.?, .get_layer_surface, .{
            .surface = wl_surface,
            .output = null,
            .layer = .top,
            .namespace = "",
        });
        client.request(layer_surface, .set_size, .{ .width = width, .height = height });
        client.request(layer_surface, .set_anchor, .{ .anchor = .{ .top = true, .left = true, .right = true } });
        client.request(layer_surface, .set_exclusive_zone, .{ .zone = 35 });
        client.request(layer_surface, .set_keyboard_interactivity, .{ .keyboard_interactivity = .exclusive });
        break :b .{
            .layer_surface = layer_surface,
            .wl_surface = wl_surface,
            .shortcut_inhibitor = shortcut_inhibitor,
            .width = width,
            .height = height,
            .last_frame = 0,
            .offset = 0,
            .ctx = &context,
        };
    };
    defer client.request(surface.wl_surface, .destroy, {});
    defer client.request(surface.layer_surface, .destroy, {});

    client.set_listener(surface.layer_surface, *Globals, layer_suface_listener, &context);
    client.request(surface.wl_surface, .commit, {});
    try client.roundtrip();

    const buf = try Buffer.get(client, shm, surface.width, surface.height);
    @memset(buf.mem(), 0xff);
    client.request(surface.wl_surface, .attach, .{ .buffer = buf.wl_buffer, .x = 0, .y = 0 });

    client.request(surface.wl_surface, .commit, {});

    try client.recvEvents();
}

fn registryListener(client: *wayland.Client, registry: wl.Registry, event: wl.Registry.Event, context: *Globals) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = client.bind(registry, global.name, wl.Compositor, 1);
            } else if (mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                context.shm = client.bind(registry, global.name, wl.Shm, 1);
            } else if (mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                context.wm_base = client.bind(registry, global.name, xdg.WmBase, 1);
            } else if (std.mem.orderZ(u8, global.interface, zwlr.LayerShellV1.interface.name) == .eq) {
                context.layer_shell = client.bind(registry, global.name, zwlr.LayerShellV1, 1);
            } else if (std.mem.orderZ(u8, global.interface, zwp.KeyboardShortcutsInhibitManagerV1.interface.name) == .eq) {
                context.shortcut_inhibit_manager = client.bind(registry, global.name, zwp.KeyboardShortcutsInhibitManagerV1, 1);
            } else if (std.mem.orderZ(u8, global.interface, wl.Seat.interface.name) == .eq) {
                context.seat = client.bind(registry, global.name, wl.Seat, 1);
                client.set_listener(context.seat.?, *Globals, seat_listener, context);
            }
        },
        .global_remove => {},
    }
}

fn xdgSurfaceListener(client: *wayland.Client, xdg_surface: xdg.Surface, event: xdg.Surface.Event, surf: *SurfaceCtx) void {
    _ = surf;
    switch (event) {
        .configure => |configure| {
            client.request(xdg_surface, .ack_configure, .{ .serial = configure.serial });
        },
    }
}

fn xdgToplevelListener(_: *wayland.Client, _: xdg.Toplevel, event: xdg.Toplevel.Event, surf: *SurfaceCtx) void {
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

fn seat_listener(client: *wayland.Client, seat: wl.Seat, event: wl.Seat.Event, app: *Globals) void {
    switch (event) {
        .capabilities => |data| {
            std.debug.print("Seat capabilities\n  Pointer {}\n  Keyboard {}\n  Touch {}\n", .{
                data.capabilities.pointer,
                data.capabilities.keyboard,
                data.capabilities.touch,
            });
            if (data.capabilities.keyboard) {
                if (app.keyboard == null) {
                    app.keyboard = client.request(seat, .get_keyboard, .{});
                    client.set_listener(app.keyboard.?, *Globals, keyboard_listener, app);
                }
            }
        },
        .name => |name| {
            std.debug.print("seat name: {s}\n", .{name.name});
        },
    }
}
fn keyboard_listener(client: *wayland.Client, _: wl.Keyboard, event: wl.Keyboard.Event, app: *Globals) void {
    _ = app; // autofix
    // std.log.info("_event={}", .{event});

    switch (event) {
        .key => |e| {
            if (e.key == 1) client.connection.is_running = false;
        },
        else => {},
    }
}

fn layer_suface_listener(client: *wayland.Client, layer_suface: zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, app: *Globals) void {
    _ = app; // autofix
    switch (event) {
        .configure => |configure| {
            client.request(layer_suface, .ack_configure, .{ .serial = configure.serial });
            std.log.info("w: {} h: {}", .{ configure.width, configure.height });
        },
        .closed => {},
    }
}

const std = @import("std");
const mem = std.mem;

const wayland = @import("wayland");
const wl = wayland.wl;
const xdg = wayland.xdg;
const zwlr = wayland.zwlr;
const zwp = wayland.zwp;

const Buffer = wayland.shm.Buffer;
