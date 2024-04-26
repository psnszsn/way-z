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
    wl_subsurface: wl.Subsurface,
},
size: Size,
min_size: Size,
last_frame: u32,
frame_done: bool = true,
initial_draw: bool = false,

pub const SurfaceType = enum {
    xdg_toplevel,
    xdg_popup,
    wlr_layer_surface,
    wl_subsurface,
};

pub const SurfaceInitOpts = union(SurfaceType) {
    xdg_toplevel: void,
    xdg_popup: struct { parent: xdg.Surface, anchor: Rect },
    wlr_layer_surface: void,
    wl_subsurface: struct { parent: wl.Surface },
};

pub fn init_wl(
    surface: *Surface,
    stype: SurfaceInitOpts,
) std.meta.FieldType(Surface, .wl) {
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
        .wl_subsurface => |opts| {
            const wl_subsurface = client.request(app.subcompositor.?, .get_subsurface, .{
                .surface = surface.wl_surface,
                .parent = opts.parent,
            });
            // errdefer client.request(wl_subsurface), .destroy, {});
            client.request(wl_subsurface, .set_sync, {});
            client.request(wl_subsurface, .set_position, .{ .x = 500, .y = 22 });

            return .{ .wl_subsurface = wl_subsurface };
        },
        .xdg_popup => |opts| {
            const xdg_surface = client.request(app.wm_base.?, .get_xdg_surface, .{ .surface = surface.wl_surface });
            errdefer client.request(xdg_surface, .destroy, {});

            const positioner = client.request(app.wm_base.?, .create_positioner, .{});
            defer client.request(positioner, .destroy, {});

            client.request(positioner, .set_size, .{
                .width = @intCast(surface.size.width),
                .height = @intCast(surface.size.height),
            });
            const anchor_rect = opts.anchor;
            client.request(positioner, .set_anchor_rect, .{
                .x = @intCast(anchor_rect.x),
                .y = @intCast(anchor_rect.y),
                .width = @intCast(anchor_rect.width),
                .height = @intCast(anchor_rect.height),
            });
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

pub fn destroy(self: *Surface) void {
    const client = self.app.client;
    // const index = (@intFromPtr(self) - @intFromPtr(self.app.surfaces.items.ptr)) / @sizeOf(Surface);
    // std.log.info("index: {}", .{index});
    switch (self.wl) {
        .xdg_popup => |x| {
            client.request(x.xdg_popup, .destroy, {});
            client.request(x.xdg_surface, .destroy, {});
        },
        .xdg_toplevel => |x| {
            _ = x; // autofix
        },

        .wlr_layer_surface => |x| {
            _ = x; // autofix
        },
        .wl_subsurface => |x| {
            client.request(x, .destroy, {});
        },
    }
    client.request(self.wl_surface, .destroy, {});
    _ = self.app.surfaces.remove(self.wl_surface);
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
            //TODO: use ptrCast directly when implemented in zig
            // .buffer = @ptrCast(buf.pool.mmap),
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

    var iter = app.layout.child_iterator(surf.root);
    while (iter.next()) |idx| {
        // const t = app.layout.get(idx, .type);
        // std.log.info("idx={} type={}", .{ idx, t });
        const rect = b: {
            var r = app.layout.get(idx, .rect);
            var parent = app.layout.get(idx, .parent);
            while (parent) |par| {
                const parent_rect = app.layout.get(par, .rect);
                r.translate_by(parent_rect.x, parent_rect.y);
                parent = app.layout.get(par, .parent);
            }
            break :b r;
        };
        _ = app.layout.call(idx, .draw, .{ rect, ctx });
    }
}

fn layer_suface_listener(client: *wlnd.Client, layer_suface: zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, surf: *Surface) void {
    switch (event) {
        .configure => |configure| {
            client.request(layer_suface, .ack_configure, .{ .serial = configure.serial });

            if (!surf.initial_draw) {
                surf.draw();
                surf.initial_draw = true;
            }

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
    switch (event) {
        .configure => |configure| {
            client.request(xdg_surface, .ack_configure, .{ .serial = configure.serial });
            if (!win.initial_draw) {
                win.draw();
                var it = win.app.surfaces.valueIterator();
                while (it.next()) |surface| {
                    if (surface.wl == .wl_subsurface) {
                        surface.draw();
                    }
                }
                win.initial_draw = true;
            }
        },
    }
}
fn xdg_toplevel_listener(_: *wlnd.Client, _: xdg.Toplevel, event: xdg.Toplevel.Event, win: *Surface) void {
    switch (event) {
        .configure => |configure| {
            const configure_size = Size{
                .width = @intCast(configure.width),
                .height = @intCast(configure.height),
            };
            if (configure_size.is_zero()) return;

            const new_size = configure_size.unite(win.min_size);
            if (new_size.is_eql(win.size)) return;

            std.log.warn("configure event {}", .{configure});

            win.size = new_size;
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
fn xdg_popup_listener(client: *wlnd.Client, xdg_popup: xdg.Popup, event: xdg.Popup.Event, win: *Surface) void {
    _ = client; // autofix
    switch (event) {
        .configure => |configure| {
            std.log.info("popup configure :{}", .{configure});
        },
        .popup_done => {
            std.log.info("popup done {}", .{xdg_popup});
            win.destroy();
            // client.request(xdg_popup, .destroy, {});
            // win.app.surfaces.orderedRemove()
        },
        else => {},
    }
}

const std = @import("std");

const App = @import("App.zig");
const PaintCtx = @import("paint.zig").PaintCtxU32;
const Point = @import("paint/Point.zig");
const Rect = @import("paint/Rect.zig");
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
const Surface = @This();
