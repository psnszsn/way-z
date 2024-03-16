const std = @import("std");
const mem = std.mem;

const wayland = @import("wayland");
const wl = wayland.wl;
const xdg = wayland.xdg;
const zwlr = wayland.zwlr;
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
shm: ?*wl.Shm = null,
compositor: ?*wl.Compositor = null,
wm_base: ?*xdg.WmBase = null,
layer_shell: ?*zwlr.LayerShellV1 = null,
seat: ?*wl.Seat = null,
pointer: ?*wl.Pointer = null,

font: *font.Font,

window: *Window = undefined,
running: bool = true,

pub fn new(alloc: std.mem.Allocator) !*App {
    const client = try wayland.Client.connect(alloc);
    const registry = client.get_registry();

    // TODO: remove allocation
    const app = try alloc.create(App);
    app.* = App{
        .client = client,
        .shm = null,
        .compositor = null,
        .wm_base = null,
        .font = try font.cozette(alloc),
    };

    registry.set_listener(*App, App.registryListener, app);
    try client.roundtrip();

    std.debug.assert(app.shm != null);
    std.debug.assert(app.compositor != null);
    std.debug.assert(app.wm_base != null);
    std.debug.assert(app.layer_shell != null);
    return app;
}

pub fn new_window(app: *App, shell: WindowType) !*Window {
    const wl_surface = app.compositor.?.create_surface();
    errdefer wl_surface.destroy();

    // TODO: remove allocation
    const window = try app.client.allocator.create(Window);

    const wl_if: std.meta.FieldType(Window, .wl) = if (shell == .wlr_layer_shell) b: {
        const layer_surface = app.layer_shell.?.get_layer_surface(wl_surface, null, .top, "");
        errdefer layer_surface.destroy();
        layer_surface.set_size(0, 30);
        layer_surface.set_anchor(.{ .top = true, .left = true, .right = true });
        layer_surface.set_exclusive_zone(35);
        layer_surface.set_listener(*Window, Window.layer_suface_listener, window);
        break :b .{ .wlr_layer_shell = layer_surface };
    } else b: {
        const xdg_surface = app.wm_base.?.get_xdg_surface(wl_surface);
        errdefer xdg_surface.destroy();
        const xdg_toplevel = xdg_surface.get_toplevel();
        errdefer xdg_toplevel.destroy();

        xdg_surface.set_listener(*Window, Window.xdg_surface_listener, window);
        xdg_toplevel.set_listener(*Window, Window.xdg_toplevel_listener, window);
        xdg_toplevel.set_title("Demo");

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

    wl_surface.commit();
    try app.client.roundtrip();

    return window;
}

const WindowType = enum {
    xdg_shell,
    wlr_layer_shell,
};

pub const Window = struct {
    app: *App,

    wl_surface: *wl.Surface,
    wl: union(WindowType) {
        xdg_shell: struct {
            xdg_surface: *xdg.Surface,
            xdg_toplevel: *xdg.Toplevel,
        },
        wlr_layer_shell: *zwlr.LayerSurfaceV1,
    },
    width: u32,
    height: u32,
    last_frame: u32,
    frame_done: bool = true,

    layout: Layout = .{},

    pub fn set_root_widget(self: *Window, idx: WidgetIdx) void {
        const min_size = Size{ .width = 10, .height = 10 };
        std.log.info("idx {}", .{idx});
        const size = self.layout.call(idx, .size, .{Size.Minmax.tight(min_size)});
        self.width = @intCast(size.width);
        self.height = @intCast(size.height);

        std.log.info("min size {}", .{size});
        self.wl.xdg_shell.xdg_toplevel.set_min_size(@intCast(size.width), @intCast(size.height));
        self.wl_surface.commit();
        self.layout.root = idx;
    }
    pub fn schedule_redraw(self: *Window) void {
        // if (!bar.frame_done) std.log.warn("not done!!!!", .{});
        if (!self.frame_done) return;
        const frame_cb = self.wl_surface.frame();
        frame_cb.set_listener(*Window, frame_listener, self);
        self.wl_surface.commit();
        self.frame_done = false;
    }

    pub fn draw(self: *Window) void {
        std.log.info("draw", .{});
        if (self.width == 0) return;
        if (self.height == 0) return;
        const buf = Buffer.get(self.app.shm.?, self.width, self.height) catch unreachable;
        const ctx = PaintCtx{
            .buffer = @ptrCast(std.mem.bytesAsSlice(u32, buf.pool.mmap)),
            .width = buf.width,
            .height = buf.height,
        };
        // @memset(buf.pool.mmap, 55);
        @memset(buf.pool.mmap, 155);
        self.layout.draw(ctx);
        self.wl_surface.attach(buf.wl_buffer, 0, 0);
        self.wl_surface.damage(0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
        self.wl_surface.commit();
    }

    fn layer_suface_listener(layer_suface: *zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, window: *Window) void {
        switch (event) {
            .configure => |configure| {
                layer_suface.ack_configure(configure.serial);

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

    fn frame_listener(cb: *wl.Callback, event: wl.Callback.Event, window: *Window) void {
        _ = cb;
        switch (event) {
            .done => |done| {
                window.draw();
                window.last_frame = done.callback_data;
                window.frame_done = true;
                // window.schedule_redraw();
            },
        }
    }

    fn xdg_surface_listener(xdg_surface: *xdg.Surface, event: xdg.Surface.Event, win: *Window) void {
        _ = win; // autofix
        switch (event) {
            .configure => |configure| {
                xdg_surface.ack_configure(configure.serial);
            },
        }
    }
    fn xdg_toplevel_listener(_: *xdg.Toplevel, event: xdg.Toplevel.Event, win: *Window) void {
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

                const widget_size = win.layout.call(win.layout.root, .size, .{
                    Size.Minmax.tight(.{ .width = win.width, .height = win.height }),
                });
                _ = widget_size; // autofix
                std.log.info("w: {} h: {}", .{ win.width, win.height });
            },
            .close => {
                win.app.running = false;
            },
            else => {},
        }
    }
};

pub fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, context: *App) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = registry.bind(global.name, wl.Compositor, 1);
            } else if (mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                context.shm = registry.bind(global.name, wl.Shm, 1);
            } else if (mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                context.wm_base = registry.bind(global.name, xdg.WmBase, 1);
            } else if (mem.orderZ(u8, global.interface, zwlr.LayerShellV1.interface.name) == .eq) {
                context.layer_shell = registry.bind(global.name, zwlr.LayerShellV1, 1);
            } else if (mem.orderZ(u8, global.interface, wl.Seat.interface.name) == .eq) {
                context.seat = registry.bind(global.name, wl.Seat, 1);
                context.seat.?.set_listener(*App, seat_listener, context);
            }
        },
        .global_remove => {},
    }
}

fn seat_listener(seat: *wl.Seat, event: wl.Seat.Event, app: *App) void {
    switch (event) {
        .capabilities => |data| {
            std.debug.print("Seat capabilities\n  Pointer {}\n  Keyboard {}\n  Touch {}\n", .{
                data.capabilities.pointer,
                data.capabilities.keyboard,
                data.capabilities.touch,
            });

            if (data.capabilities.pointer) {
                if (app.pointer == null) {
                    app.pointer = seat.get_pointer();
                    app.pointer.?.set_listener(*App, pointer_listener, app);
                }
            }
        },
        .name => |name| {
            std.debug.print("seat name: {s}\n", .{name.name});
        },
    }
}

fn pointer_listener(_: *wl.Pointer, _event: wl.Pointer.Event, app: *App) void {
    const win = app.window;
    const event: ?Event.PointerEvent = switch (_event) {
        inline .motion, .enter => |ev| blk: {
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
    for (win.layout.widgets.items(.rect), 0..) |rect, i| {
        const idx: WidgetIdx = @enumFromInt(i);
        const was_pressed = win.layout.get(idx, .pressed);
        const was_hover = win.layout.get(idx, .hover);
        const is_hover = rect.contains_point(win.layout.pointer_position);

        if (is_hover != was_hover) {
            win.layout.set(idx, .hover, is_hover);
            const ev = Event{ .pointer = if (is_hover) .{ .enter = {} } else .{ .leave = {} } };
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
}
