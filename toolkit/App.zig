const std = @import("std");
const mem = std.mem;

const wayland = @import("wayland");
const wl = wayland.wl;
const xdg = wayland.xdg;
const zwlr = wayland.zwlr;
const wp = wayland.wp;
const App = @This();

const font = @import("font/bdf.zig");

const Buffer = wayland.shm.Buffer;
const PaintCtx = @import("paint.zig").PaintCtxU32;
const Size = @import("paint/Size.zig");
const Point = @import("paint/Point.zig");
const w = @import("widget.zig");
const WidgetIdx = w.WidgetIdx;
const Layout = w.Layout;
const Event = @import("event.zig").Event;

client: *wayland.Client,
shm: ?wl.Shm = null,
compositor: ?wl.Compositor = null,
wm_base: ?xdg.WmBase = null,
layer_shell: ?zwlr.LayerShellV1 = null,
cursor_shape_manager: ?wp.CursorShapeManagerV1 = null,
seat: ?wl.Seat = null,
cursor_shape_device: ?wp.CursorShapeDeviceV1 = null,
cursor_shape: wp.CursorShapeDeviceV1.Shape = .default,
pointer_enter_serial: u32 = 0,
pointer: ?wl.Pointer = null,

font: *font.Font,

window: *Window = undefined,
running: bool = true,

pub fn new(alloc: std.mem.Allocator) !*App {
    const client = try wayland.Client.connect(alloc);
    const registry = client.wl_display.get_registry(client);

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
    std.debug.assert(app.layer_shell != null);
    return app;
}

pub fn new_window(app: *App, shell: WindowType) !*Window {
    const client = app.client;
    const wl_surface = app.compositor.?.create_surface(client);
    errdefer wl_surface.destroy(client);

    // TODO: remove allocation
    const window = try app.client.allocator.create(Window);

    const wl_if: std.meta.FieldType(Window, .wl) = if (shell == .wlr_layer_shell) b: {
        const layer_surface = app.layer_shell.?.get_layer_surface(client, wl_surface, null, .top, "");
        errdefer layer_surface.destroy(client);
        layer_surface.set_size(client, 0, 30);
        layer_surface.set_anchor(client, .{ .top = true, .left = true, .right = true });
        layer_surface.set_exclusive_zone(client, 35);
        client.set_listener(layer_surface, *Window, Window.layer_suface_listener, window);
        break :b .{ .wlr_layer_shell = layer_surface };
    } else b: {
        const xdg_surface = app.wm_base.?.get_xdg_surface(client, wl_surface);
        errdefer xdg_surface.destroy(client);
        const xdg_toplevel = xdg_surface.get_toplevel(client);
        errdefer xdg_toplevel.destroy(client);

        client.set_listener(xdg_surface, *Window, Window.xdg_surface_listener, window);
        client.set_listener(xdg_toplevel, *Window, Window.xdg_toplevel_listener, window);
        xdg_toplevel.set_title(client, "Demo");

        break :b .{ .xdg_shell = .{
            .xdg_surface = xdg_surface,
            .xdg_toplevel = xdg_toplevel,
        } };
    };

    window.* = .{
        .app = app,
        .wl_surface = wl_surface,
        .wl = wl_if,
        .width = 300,
        .height = 300,
        .last_frame = 0,
    };

    app.window = window;

    wl_surface.commit(client);
    try app.client.roundtrip();

    return window;
}

const WindowType = enum {
    xdg_shell,
    wlr_layer_shell,
};

pub const Window = struct {
    app: *App,

    wl_surface: wl.Surface,
    wl: union(WindowType) {
        xdg_shell: struct {
            xdg_surface: xdg.Surface,
            xdg_toplevel: xdg.Toplevel,
        },
        wlr_layer_shell: zwlr.LayerSurfaceV1,
    },
    width: u32,
    height: u32,
    last_frame: u32,
    frame_done: bool = true,

    layout: Layout = .{},

    pub fn set_root_widget(self: *Window, idx: WidgetIdx) void {
        const c = self.app.client;
        const min_size = Size{ .width = 10, .height = 10 };
        std.log.info("idx {}", .{idx});
        const size = self.layout.call(idx, .size, .{Size.Minmax.tight(min_size)});
        self.width = @intCast(size.width);
        self.height = @intCast(size.height);

        std.log.info("min size {}", .{size});
        if (self.wl == .xdg_shell) {
            self.wl.xdg_shell.xdg_toplevel.set_min_size(c, @intCast(size.width), @intCast(size.height));
        }
        self.wl_surface.commit(c);
        self.layout.root = idx;
    }
    pub fn schedule_redraw(self: *Window) void {
        if (!self.frame_done) return;
        const client = self.app.client;
        const frame_cb = self.wl_surface.frame(client);
        client.set_listener(frame_cb, *Window, frame_listener, self);
        self.wl_surface.commit(client);
        self.frame_done = false;
    }

    pub fn draw(self: *Window) void {
        std.log.info("draw", .{});
        const client = self.app.client;
        if (self.width == 0) return;
        if (self.height == 0) return;
        const buf = Buffer.get(self.app.client, self.app.shm.?, self.width, self.height) catch unreachable;
        const ctx = PaintCtx{
            .buffer = @ptrCast(std.mem.bytesAsSlice(u32, buf.pool.mmap)),
            .width = buf.width,
            .height = buf.height,
        };
        @memset(buf.pool.mmap, 155);
        self.layout.draw(ctx);
        self.wl_surface.attach(client, buf.wl_buffer, 0, 0);
        self.wl_surface.damage(client, 0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
        self.wl_surface.commit(client);
    }

    fn layer_suface_listener(client: *wayland.Client, layer_suface: zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, window: *Window) void {
        switch (event) {
            .configure => |configure| {
                layer_suface.ack_configure(client, configure.serial);

                window.width = configure.width;
                window.height = configure.height;

                std.log.info("w: {} h: {}", .{ window.width, window.height });

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

    fn frame_listener(client: *wayland.Client, cb: wl.Callback, event: wl.Callback.Event, window: *Window) void {
        _ = client; // autofix
        _ = cb;
        switch (event) {
            .done => |done| {
                window.draw();
                window.last_frame = done.callback_data;
                window.frame_done = true;
            },
        }
    }

    fn xdg_surface_listener(client: *wayland.Client, xdg_surface: xdg.Surface, event: xdg.Surface.Event, _: *Window) void {
        switch (event) {
            .configure => |configure| {
                xdg_surface.ack_configure(client, configure.serial);
            },
        }
    }
    fn xdg_toplevel_listener(client: *wayland.Client, _: xdg.Toplevel, event: xdg.Toplevel.Event, win: *Window) void {
        _ = client; // autofix
        switch (event) {
            .configure => |configure| {
                if (configure.width == 0) return;
                if (configure.height == 0) return;

                if (win.width == configure.width and
                    win.height == configure.height) return;

                std.log.warn("configure event {}", .{configure});

                win.width = @intCast(configure.width);
                win.height = @intCast(configure.height);

                win.schedule_redraw();

                _ = win.layout.call(win.layout.root, .size, .{
                    Size.Minmax.tight(.{ .width = win.width, .height = win.height }),
                });
                std.log.info("w: {} h: {}", .{ win.width, win.height });
            },
            .close => {
                win.app.running = false;
            },
            else => {},
        }
    }
};

pub fn registryListener(client: *wayland.Client, registry: wl.Registry, event: wl.Registry.Event, context: *App) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = registry.bind(client, global.name, wl.Compositor, 1);
            } else if (mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                context.shm = registry.bind(client, global.name, wl.Shm, 1);
            } else if (mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                context.wm_base = registry.bind(client, global.name, xdg.WmBase, 1);
            } else if (mem.orderZ(u8, global.interface, zwlr.LayerShellV1.interface.name) == .eq) {
                context.layer_shell = registry.bind(client, global.name, zwlr.LayerShellV1, 1);
            } else if (mem.orderZ(u8, global.interface, wp.CursorShapeManagerV1.interface.name) == .eq) {
                context.cursor_shape_manager = registry.bind(client, global.name, wp.CursorShapeManagerV1, 1);
            } else if (mem.orderZ(u8, global.interface, wl.Seat.interface.name) == .eq) {
                context.seat = registry.bind(client, global.name, wl.Seat, 1);
                client.set_listener(context.seat.?, *App, seat_listener, context);
            }
        },
        .global_remove => {},
    }
}

fn seat_listener(client: *wayland.Client, seat: wl.Seat, event: wl.Seat.Event, app: *App) void {
    switch (event) {
        .capabilities => |data| {
            std.debug.print("Seat capabilities\n  Pointer {}\n  Keyboard {}\n  Touch {}\n", .{
                data.capabilities.pointer,
                data.capabilities.keyboard,
                data.capabilities.touch,
            });

            if (data.capabilities.pointer) {
                if (app.pointer == null) {
                    app.pointer = seat.get_pointer(client);
                    client.set_listener(app.pointer.?, *App, pointer_listener, app);
                    if (app.cursor_shape_manager) |csm| {
                        app.cursor_shape_device = csm.get_pointer(client, app.pointer.?);
                    }
                }
            }
        },
        .name => |name| {
            std.debug.print("seat name: {s}\n", .{name.name});
        },
    }
}

fn pointer_listener(client: *wayland.Client, _: wl.Pointer, _event: wl.Pointer.Event, app: *App) void {
    const win = app.window;
    const event: ?Event.PointerEvent = switch (_event) {
        .enter => |ev| blk: {
            win.layout.pointer_position = Point{ .x = @abs(ev.surface_x.toInt()), .y = @abs(ev.surface_y.toInt()) };
            app.pointer_enter_serial = ev.serial;
            break :blk null;
        },
        .motion => |ev| blk: {
            win.layout.pointer_position = Point{ .x = @abs(ev.surface_x.toInt()), .y = @abs(ev.surface_y.toInt()) };
            break :blk null;
        },
        .leave => blk: {
            win.layout.pointer_position = Point.INF;
            @memset(win.layout.widgets.items(.pressed), false);
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

    for (win.layout.widgets.items(.rect), 0..) |rect, i| {
        const idx: WidgetIdx = @enumFromInt(i);
        const was_pressed = win.layout.get(idx, .pressed);
        const was_hover = win.layout.get(idx, .hover);
        const is_hover = rect.contains_point(win.layout.pointer_position);

        if (is_hover != was_hover) {
            // TODO: root widget is always hovered
            win.layout.set(idx, .hover, is_hover);
            const ev = Event{ .pointer = if (is_hover) .{ .enter = {} } else .{ .leave = {} } };
            if (is_hover) win.layout.set_cursor_shape(.default);
            win.layout.call(idx, .handle_event, .{ev});
        }

        if (event) |ev| {
            if (is_hover or was_pressed) {
                if (ev == .button) {
                    win.layout.set(idx, .pressed, ev.button.state == .pressed);
                }
                win.layout.call(idx, .handle_event, .{Event{ .pointer = ev }});
            }
        }
    }
    if (old_shape != app.cursor_shape) app.cursor_shape_device.?.set_shape(client, app.pointer_enter_serial, app.cursor_shape);
}
