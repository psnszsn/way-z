client: *wlnd.Client,

// Wayland object ids
// zig fmt: off
shm                 : ?wl.Shm                  = null,
compositor          : ?wl.Compositor           = null,
wm_base             : ?xdg.WmBase              = null,
layer_shell         : ?zwlr.LayerShellV1       = null,
seat                : ?wl.Seat                 = null,
cursor_shape_manager: ?wp.CursorShapeManagerV1 = null,
cursor_shape_device : ?wp.CursorShapeDeviceV1  = null,
pointer             : ?wl.Pointer              = null,
subcompositor       : ?wl.Subcompositor        = null,
// zig fmt: on

font: *font.Font,
pointer_enter_serial: u32 = 0,
cursor_shape: wp.CursorShapeDeviceV1.Shape = .default,

// surfaces: std.ArrayListUnmanaged(Surface) = .{},
surfaces: std.AutoHashMapUnmanaged(wl.Surface, Surface) = .{},
active_surface: ?wl.Surface = null,

layout: Layout = .{},
pointer_position: Point = Point.ZERO,

pub fn new(alloc: std.mem.Allocator) !*App {
    const client = try wlnd.Client.connect(alloc);
    const registry = client.request(client.wl_display, .get_registry, .{});

    // TODO: remove allocation
    const app = try alloc.create(App);
    app.* = App{
        .client = client,
        .shm = null,
        .compositor = null,
        .wm_base = null,
        .font = try font.cozette(alloc),
    };

    client.set_listener(registry, *App, App.registry_listener, app);
    try client.roundtrip();

    std.debug.assert(app.shm != null);
    std.debug.assert(app.compositor != null);
    std.debug.assert(app.wm_base != null);
    return app;
}
pub fn deinit(app: *App) void {
    const alloc = app.client.allocator;
    app.client.deinit();
    app.layout.deinit(alloc);
    alloc.destroy(app.font);
    app.surfaces.deinit(alloc);
    alloc.destroy(app);
}

pub fn new_surface(app: *App, opts: Surface.SurfaceRoleInit, root_widget: WidgetIdx) !*Surface {
    const surf = try new_common(app, root_widget);

    surf.role = Surface.init_role(surf, opts);

    app.client.request(surf.wl_surface, .commit, {});
    return surf;
}

pub fn new_common(app: *App, root_widget: WidgetIdx) !*Surface {
    const client = app.client;
    const wl_surface = client.request(app.compositor.?, .create_surface, .{});
    errdefer client.request(wl_surface, .destroy, {});

    const result = try app.surfaces.getOrPut(app.client.allocator, wl_surface);
    const surf = result.value_ptr;

    const size = app.layout.call(root_widget, .size, .{Size.Minmax.ZERO});
    app.layout.set(root_widget, .rect, size.to_rect());
    surf.* = .{
        .app = app,
        .wl_surface = wl_surface,
        .role = undefined,
        .min_size = size,
        .size = size,
        .last_frame = 0,
        .root = root_widget,
        .pool = try wlnd.shm.Pool.init(client, app.shm.?, size.width, size.height),
    };

    return surf;
}

pub fn find_wl_surface(app: *App, wl_surface: wlnd.wl.Surface) ?*Surface {
    var it = app.surfaces.valueIterator();
    while (it.next()) |surface| {
        if (surface.wl_surface == wl_surface) {
            return surface;
        }
    }
    return null;
}

pub fn registry_listener(client: *wlnd.Client, registry: wl.Registry, event: wl.Registry.Event, context: *App) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = client.bind(registry, global.name, wl.Compositor, global.version);
            } else if (std.mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                context.shm = client.bind(registry, global.name, wl.Shm, global.version);
            } else if (std.mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                context.wm_base = client.bind(registry, global.name, xdg.WmBase, global.version);
            } else if (std.mem.orderZ(u8, global.interface, zwlr.LayerShellV1.interface.name) == .eq) {
                context.layer_shell = client.bind(registry, global.name, zwlr.LayerShellV1, global.version);
            } else if (std.mem.orderZ(u8, global.interface, wp.CursorShapeManagerV1.interface.name) == .eq) {
                context.cursor_shape_manager = client.bind(registry, global.name, wp.CursorShapeManagerV1, global.version);
            } else if (std.mem.orderZ(u8, global.interface, wl.Subcompositor.interface.name) == .eq) {
                context.subcompositor = client.bind(registry, global.name, wl.Subcompositor, global.version);
            } else if (std.mem.orderZ(u8, global.interface, wl.Seat.interface.name) == .eq) {
                context.seat = client.bind(registry, global.name, wl.Seat, global.version);
                client.set_listener(context.seat.?, *App, seat_listener, context);
            }
        },
        .global_remove => {},
    }
}

fn seat_listener(client: *wlnd.Client, seat: wl.Seat, event: wl.Seat.Event, app: *App) void {
    switch (event) {
        .capabilities => |data| {
            std.debug.print("Seat capabilities\n  Pointer {}\n  Keyboard {}\n  Touch {}\n", .{
                data.capabilities.pointer,
                data.capabilities.keyboard,
                data.capabilities.touch,
            });

            if (data.capabilities.pointer) {
                if (app.pointer == null) {
                    app.pointer = client.request(seat, .get_pointer, .{});
                    client.set_listener(app.pointer.?, *App, pointer_listener, app);
                    if (app.cursor_shape_manager) |csm| {
                        app.cursor_shape_device = client.request(csm, .get_pointer, .{ .pointer = app.pointer.? });
                    }
                }
            }
        },
        .name => |name| {
            std.debug.print("seat name: {s}\n", .{name.name});
        },
    }
}

fn pointer_listener(client: *wlnd.Client, _: wl.Pointer, _event: wl.Pointer.Event, app: *App) void {
    const event: ?Event.PointerEvent = switch (_event) {
        .enter => |ev| blk: {
            std.log.info("ENter  - {}", .{ev});
            app.pointer_position = Point{ .x = @abs(ev.surface_x.toInt()), .y = @abs(ev.surface_y.toInt()) };
            app.pointer_enter_serial = ev.serial;
            app.active_surface = ev.surface;
            break :blk null;
        },
        .motion => |ev| blk: {
            app.pointer_position = Point{ .x = @abs(ev.surface_x.toInt()), .y = @abs(ev.surface_y.toInt()) };
            break :blk null;
        },
        .leave => blk: {
            app.pointer_position = Point.INF;
            @memset(app.layout.widgets.items(.pressed), false);
            break :blk .{ .leave = {} };
        },
        .button => |ev| blk: {
            break :blk .{ .button = .{ .button = @enumFromInt(ev.button), .state = ev.state } };
        },
        .frame => |_| blk: {
            // TODO
            break :blk null;
        },
        else => |d| blk: {
            std.log.info("pointer event: {}", .{d});
            break :blk null;
        },
    };
    const old_shape = app.cursor_shape;

    const active_surface = app.surfaces.getPtr(app.active_surface.?) orelse return;
    var iter = app.layout.child_iterator(active_surface.root);
    while (iter.next()) |idx| {
        // std.log.info("id: {}", .{idx});
        const rect = app.layout.get(idx, .rect);
        const was_pressed = app.layout.get(idx, .pressed);
        const was_hover = app.layout.get(idx, .hover);
        const is_hover = rect.contains_point(app.pointer_position);

        if (is_hover != was_hover) {
            // TODO: root widget is always hovered
            // std.log.info(" hover id: {}", .{idx});
            app.layout.set(idx, .hover, is_hover);
            const ev = Event{ .pointer = if (is_hover) .{ .enter = {} } else .{ .leave = {} } };
            if (is_hover) app.layout.set_cursor_shape(.default);
            app.layout.call(idx, .handle_event, .{ev});
        }

        if (event) |ev| {
            if (is_hover or was_pressed) {
                if (ev == .button) {
                    app.layout.set(idx, .pressed, ev.button.state == .pressed);
                    if (ev.button.state == .released)
                        app.layout.call(idx, .handle_event, .{.{ .pointer = .leave }});
                }
            }
            if (is_hover) {
                app.layout.call(idx, .handle_event, .{Event{ .pointer = ev }});
            }
        }
    }
    if (old_shape != app.cursor_shape) client.request(app.cursor_shape_device.?, .set_shape, .{
        .serial = app.pointer_enter_serial,
        .shape = app.cursor_shape,
    });
}

const std = @import("std");

const App = @This();
const Point = @import("paint/Point.zig");
const Size = @import("paint/Size.zig");
const font = @import("font/bdf.zig");
const Event = @import("event.zig").Event;
pub const Surface = @import("Surface.zig");

const w = @import("widget.zig");
const Layout = w.Layout;
const WidgetIdx = w.WidgetIdx;

const wlnd = @import("wayland");
const wl = wlnd.wl;
const wp = wlnd.wp;
const xdg = wlnd.xdg;
const zwlr = wlnd.zwlr;
