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
// zig fmt: on

font: *font.Font,
pointer_enter_serial: u32 = 0,
cursor_shape: wp.CursorShapeDeviceV1.Shape = .default,

surfaces: std.ArrayListUnmanaged(Surface) = .{},
active_surface: ?*Surface = null,

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

    client.set_listener(registry, *App, App.registryListener, app);
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

pub fn new_window(app: *App, shell: SurfaceType, root_widget: WidgetIdx) !*Surface {
    return new__(app, shell, root_widget, null);
}
pub fn new_popup(app: *App, parent: *Surface, root_widget: WidgetIdx) !*Surface {
    return new__(app, .xdg_popup, root_widget, parent);
}

pub fn new__(app: *App, shell: SurfaceType, root_widget: WidgetIdx, parent: ?*Surface) !*Surface {
    const client = app.client;
    const wl_surface = client.request(app.compositor.?, .create_surface, .{});
    errdefer client.request(wl_surface, .destroy, {});

    const surf = try app.surfaces.addOne(app.client.allocator);

    const size = app.layout.call(root_widget, .size, .{Size.Minmax.ZERO});
    surf.* = .{
        .app = app,
        .wl_surface = wl_surface,
        .wl = undefined,
        .size = size,
        .min_size = size,
        .last_frame = 0,
        .root = root_widget,
    };

    surf.wl = Surface.init_wl(surf, shell, .{ .parent = if (parent) |p| p.wl.xdg_toplevel.xdg_surface else null });

    client.request(wl_surface, .commit, {});
    try client.roundtrip();

    surf.draw();

    return surf;
}

const SurfaceType = enum {
    xdg_toplevel,
    xdg_popup,
    wlr_layer_surface,
};

pub const Surface = struct {
    app: *App,
    root: WidgetIdx = undefined,

    wl_surface: wl.Surface,
    wl: union(SurfaceType) {
        xdg_toplevel: struct {
            xdg_surface: xdg.Surface,
            xdg_toplevel: xdg.Toplevel,
        },
        xdg_popup: struct {
            xdg_surface: xdg.Surface,
            xdg_popup: xdg.Popup,
        },
        wlr_layer_surface: zwlr.LayerSurfaceV1,
    },
    size: Size,
    min_size: Size,
    last_frame: u32,
    frame_done: bool = true,

    pub fn init_wl(surface: *Surface, stype: SurfaceType, opts: struct { parent: ?xdg.Surface = null }) std.meta.FieldType(Surface, .wl) {
        const app = surface.app;
        const client = app.client;
        switch (stype) {
            .wlr_layer_surface => {
                std.debug.assert(app.layer_shell != null);
                const layer_surface = client.request(app.layer_shell.?, .get_layer_surface, .{
                    .surface = surface.wl_surface,
                    .output = null,
                    .layer = .bottom,
                    .namespace = "",
                });
                errdefer client.request(layer_surface, .destroy, {});
                client.request(layer_surface, .set_size, .{ .width = 0, .height = 30 });
                client.request(layer_surface, .set_anchor, .{ .anchor = .{ .top = true, .left = true, .right = true } });
                client.request(layer_surface, .set_exclusive_zone, .{ .zone = 35 });
                client.set_listener(layer_surface, *Surface, Surface.layer_suface_listener, surface);

                return .{ .wlr_layer_surface = layer_surface };
            },
            .xdg_toplevel => {
                const xdg_surface = client.request(app.wm_base.?, .get_xdg_surface, .{ .surface = surface.wl_surface });
                errdefer client.request(xdg_surface, .destroy, {});
                const xdg_toplevel = client.request(xdg_surface, .get_toplevel, .{});
                errdefer client.request(xdg_toplevel, .destroy, {});

                client.set_listener(xdg_surface, *Surface, Surface.xdg_surface_listener, surface);
                client.set_listener(xdg_toplevel, *Surface, Surface.xdg_toplevel_listener, surface);
                client.request(xdg_toplevel, .set_title, .{ .title = "Demo" });
                client.request(xdg_toplevel, .set_min_size, .{
                    .width = @intCast(surface.size.width),
                    .height = @intCast(surface.size.height),
                });

                return .{ .xdg_toplevel = .{
                    .xdg_surface = xdg_surface,
                    .xdg_toplevel = xdg_toplevel,
                } };
            },
            .xdg_popup => {
                const xdg_surface = client.request(app.wm_base.?, .get_xdg_surface, .{ .surface = surface.wl_surface });
                errdefer client.request(xdg_surface, .destroy, {});

                const positioner = client.request(app.wm_base.?, .create_positioner, .{});
                defer client.request(positioner, .destroy, {});

                client.request(positioner, .set_size, .{ .width = 200, .height = 200 });
                client.request(positioner, .set_anchor_rect, .{ .x = 10, .y = 10, .width = 200, .height = 200 });
                client.request(positioner, .set_anchor, .{ .anchor = .bottom });
                client.request(positioner, .set_gravity, .{ .gravity = .bottom });

                const xdg_popup = client.request(xdg_surface, .get_popup, .{
                    .parent = opts.parent,
                    .positioner = positioner,
                });
                errdefer client.request(xdg_popup, .destroy, {});

                client.set_listener(xdg_surface, *Surface, Surface.xdg_surface_listener, surface);
                client.set_listener(xdg_popup, *Surface, Surface.xdg_popup_listener, surface);

                return .{ .xdg_popup = .{
                    .xdg_surface = xdg_surface,
                    .xdg_popup = xdg_popup,
                } };
            },
        }
    }

    pub fn schedule_redraw(self: *Surface) void {
        if (!self.frame_done) return;
        const client = self.app.client;
        const frame_cb = client.request(self.wl_surface, .frame, .{});
        client.set_listener(frame_cb, *Surface, frame_listener, self);
        client.request(self.wl_surface, .commit, {});
        self.frame_done = false;
    }

    pub fn draw(self: *Surface) void {
        std.log.info("draw {}", .{std.meta.activeTag(self.wl)});
        const client = self.app.client;
        const buf = Buffer.get(self.app.client, self.app.shm.?, self.size.width, self.size.height) catch unreachable;
        if (self.size.contains(self.min_size)) {
            const ctx = PaintCtx{
                .buffer = @ptrCast(std.mem.bytesAsSlice(u32, buf.pool.mmap)),
                .width = buf.width,
                .height = buf.height,
            };
            @memset(buf.pool.mmap, 155);
            self.draw_root_widget(ctx);
        } else {
            @memset(buf.pool.mmap, 200);
        }
        client.request(self.wl_surface, .attach, .{ .buffer = buf.wl_buffer, .x = 0, .y = 0 });
        client.request(self.wl_surface, .damage, .{
            .x = 0,
            .y = 0,
            .width = std.math.maxInt(i32),
            .height = std.math.maxInt(i32),
        });
        client.request(self.wl_surface, .commit, {});
    }

    pub fn draw_root_widget(surf: *Surface, ctx: PaintCtx) void {
        const app = surf.app;
        app.layout.widgets.items(.rect)[@intFromEnum(surf.root)] = .{
            .x = 0,
            .y = 0,
            .width = ctx.width,
            .height = ctx.height,
        };

        _ = app.layout.call(surf.root, .draw, .{ app.layout.get(surf.root, .rect), ctx });
    }

    fn layer_suface_listener(client: *wlnd.Client, layer_suface: zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, surf: *Surface) void {
        switch (event) {
            .configure => |configure| {
                client.request(layer_suface, .ack_configure, .{ .serial = configure.serial });

                surf.size = .{
                    .width = configure.width,
                    .height = configure.height,
                };

                std.log.info("w: {} h: {}", .{ surf.size.width, surf.size.height });

                // if (self.anchor.top and self.anchor.bottom) {
                //     self.size.height = @as(usize, @intCast(configure.height));
                // }
                // if (self.anchor.left and self.anchor.right) {
                //     self.size.width = @as(usize, @intCast(configure.width));
                // }
                //
                // self.size = self.widget.size(self.size.toMinmaxTight());
                //
                // self.redraw();
            },
            .closed => {},
        }
    }

    fn frame_listener(_: *wlnd.Client, _: wl.Callback, event: wl.Callback.Event, surf: *Surface) void {
        switch (event) {
            .done => |done| {
                surf.draw();
                // std.log.warn("FRAME DONE!!! {s}", .{@tagName(surf.wl)});
                surf.last_frame = done.callback_data;
                surf.frame_done = true;
            },
        }
    }

    fn xdg_surface_listener(client: *wlnd.Client, xdg_surface: xdg.Surface, event: xdg.Surface.Event, win: *Surface) void {
        _ = win; // autofix
        switch (event) {
            .configure => |configure| {
                client.request(xdg_surface, .ack_configure, .{ .serial = configure.serial });
            },
        }
    }
    fn xdg_toplevel_listener(_: *wlnd.Client, _: xdg.Toplevel, event: xdg.Toplevel.Event, win: *Surface) void {
        switch (event) {
            .configure => |configure| {
                if (configure.width == 0) return;
                if (configure.height == 0) return;

                if (win.size.width == configure.width and
                    win.size.height == configure.height) return;

                std.log.warn("configure event {}", .{configure});

                win.size = .{
                    .width = @intCast(configure.width),
                    .height = @intCast(configure.height),
                };

                win.schedule_redraw();

                _ = win.app.layout.call(win.root, .size, .{
                    Size.Minmax.tight(win.size),
                });
                std.log.info("w: {} h: {}", .{ win.size.width, win.size.height });
            },
            .close => {
                win.app.client.connection.is_running = false;
            },
            else => {},
        }
    }
    fn xdg_popup_listener(_: *wlnd.Client, _: xdg.Popup, event: xdg.Popup.Event, win: *Surface) void {
        _ = win; // autofix
        switch (event) {
            .configure => |configure| {
                std.log.info("popup configure :{}", .{configure});
            },
            .popup_done => {
                std.log.info("popup done", .{});
            },
            else => {},
        }
    }
};

pub fn registryListener(client: *wlnd.Client, registry: wl.Registry, event: wl.Registry.Event, context: *App) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = client.bind(registry, global.name, wl.Compositor, 1);
            } else if (std.mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                context.shm = client.bind(registry, global.name, wl.Shm, 1);
            } else if (std.mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                context.wm_base = client.bind(registry, global.name, xdg.WmBase, 1);
            } else if (std.mem.orderZ(u8, global.interface, zwlr.LayerShellV1.interface.name) == .eq) {
                context.layer_shell = client.bind(registry, global.name, zwlr.LayerShellV1, 1);
            } else if (std.mem.orderZ(u8, global.interface, wp.CursorShapeManagerV1.interface.name) == .eq) {
                context.cursor_shape_manager = client.bind(registry, global.name, wp.CursorShapeManagerV1, 1);
            } else if (std.mem.orderZ(u8, global.interface, wl.Seat.interface.name) == .eq) {
                context.seat = client.bind(registry, global.name, wl.Seat, 1);
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
            for (app.surfaces.items) |*surface| {
                if (surface.wl_surface == ev.surface) {
                    std.log.info("activer surface: {}", .{surface.wl_surface});
                    app.active_surface = surface;
                }
            }
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
        else => |d| blk: {
            std.log.info("pointer event: {}", .{d});
            break :blk null;
        },
    };
    const old_shape = app.cursor_shape;

    var iter = app.layout.child_iterator(app.active_surface.?.root);
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
                }
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
const PaintCtx = @import("paint.zig").PaintCtxU32;
const Point = @import("paint/Point.zig");
const Size = @import("paint/Size.zig");
const font = @import("font/bdf.zig");
const Event = @import("event.zig").Event;

const w = @import("widget.zig");
const Layout = w.Layout;
const WidgetIdx = w.WidgetIdx;

const wlnd = @import("wayland");
const wl = wlnd.wl;
const wp = wlnd.wp;
const xdg = wlnd.xdg;
const zwlr = wlnd.zwlr;
const Buffer = wlnd.shm.Buffer;
