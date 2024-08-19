app: *App,
root: WidgetIdx = undefined,

wl_surface: wl.Surface,
role: union(SurfaceRole) {
    const Role = @This();
    xdg_toplevel: struct {
        xdg_surface: xdg.Surface,
        xdg_toplevel: xdg.Toplevel,
    },
    xdg_popup: struct {
        xdg_surface: xdg.Surface,
        xdg_popup: xdg.Popup,
    },
    wlr_layer_surface: zwlr.LayerSurfaceV1,
    wl_subsurface: struct {
        wl_subsurface: wl.Subsurface,
        pub fn set_position(self: *@This(), x: u32, y: u32) void {
            const role: *Role = @fieldParentPtr("wl_subsurface", self);
            const surface: *Surface = @alignCast(@fieldParentPtr("role", role));
            const client = surface.app.client;

            client.request(self.wl_subsurface, .set_position, .{ .x = @intCast(x), .y = @intCast(y) });
            client.request(surface.wl_surface, .commit, {});
        }
    },
},
size: Size,
min_size: Size,
last_frame: u32,
frame_done: bool = true,
initial_draw: bool = false,
pool: shm.AutoMemPool = undefined,

pub const SurfaceRole = enum {
    xdg_toplevel,
    xdg_popup,
    wlr_layer_surface,
    wl_subsurface,
};

pub const SurfaceRoleInit = union(SurfaceRole) {
    xdg_toplevel: void,
    xdg_popup: struct { parent: xdg.Surface, anchor: Rect },
    wlr_layer_surface: void,
    wl_subsurface: struct { parent: wl.Surface },
};

pub fn init_role(
    surface: *Surface,
    role: SurfaceRoleInit,
) std.meta.FieldType(Surface, .role) {
    const app = surface.app;
    const client = app.client;
    switch (role) {
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
                .width = @intCast(surface.min_size.width),
                .height = @intCast(surface.min_size.height),
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
            client.request(wl_subsurface, .set_desync, {});
            client.request(wl_subsurface, .set_position, .{ .x = 500, .y = 22 });

            surface.draw();

            return .{ .wl_subsurface = .{ .wl_subsurface = wl_subsurface } };
        },
        .xdg_popup => |opts| {
            const xdg_surface = client.request(app.wm_base.?, .get_xdg_surface, .{ .surface = surface.wl_surface });
            errdefer client.request(xdg_surface, .destroy, {});

            const positioner = client.request(app.wm_base.?, .create_positioner, .{});
            defer client.request(positioner, .destroy, {});

            client.request(positioner, .set_size, .{
                .width = @intCast(surface.min_size.width),
                .height = @intCast(surface.min_size.height),
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
    switch (self.role) {
        .xdg_popup => |x| {
            client.request(x.xdg_popup, .destroy, {});
            client.request(x.xdg_surface, .destroy, {});
        },
        .xdg_toplevel => |_| {},

        .wlr_layer_surface => |_| {},
        .wl_subsurface => |x| {
            client.request(x.wl_subsurface, .destroy, {});
        },
    }
    client.request(self.wl_surface, .destroy, {});
    _ = self.app.surfaces.remove(self.wl_surface);
}

pub fn re_size(surf: *Surface) void {
    surf.app.layout.set_size(surf.root, Size.Minmax.tight(surf.size));
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
    // std.log.info("draw {}", .{std.meta.activeTag(self.role)});
    const client = self.app.client;
    const size = self.app.layout.get(self.root, .rect).get_size();
    const buf = self.pool.buffer(client, size.width, size.height);
    if (size.contains(self.min_size)) {
        const ctx = PaintCtx{
            .buffer = @ptrCast(std.mem.bytesAsSlice(u32, buf.mem())),
            //TODO: use ptrCast directly when implemented in zig
            // .buffer = @ptrCast(buf.pool.mmap),
            .width = buf.width,
            .height = buf.height,
            .clip = size.to_rect(),
        };
        @memset(buf.mem(), 155);
        self.draw_root_widget(ctx);
    } else {
        @memset(buf.mem(), 200);
    }
    client.request(self.wl_surface, .attach, .{ .buffer = buf.wl_buffer, .x = 0, .y = 0 });
    // client.request(self.wl_surface, .offset, .{ .x = 220, .y = 220 });
    client.request(self.wl_surface, .damage_buffer, .{
        .x = 0,
        .y = 0,
        .width = std.math.maxInt(i32),
        .height = std.math.maxInt(i32),
    });
    client.request(self.wl_surface, .commit, {});
}

pub fn draw_root_widget(surf: *Surface, ctx: PaintCtx) void {
    const layout = &surf.app.layout;
    var iter = layout.child_iterator(surf.root);
    while (iter.next()) |idx| {
        const rect = layout.absolute_rect(idx);
        const ctxx = ctx.with_clip(rect);
        _ = layout.call(idx, .draw, .{ rect, ctxx });
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

            const size = Size{
                .width = @intCast(configure.width),
                .height = @intCast(configure.height),
            };

            surf.app.layout.set(surf.root, .rect, size.to_rect());

            // std.log.info("w: {} h: {}", .{ surf.size.width, surf.size.height });

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

fn xdg_surface_listener(client: *wlnd.Client, xdg_surface: xdg.Surface, event: xdg.Surface.Event, surf: *Surface) void {
    switch (event) {
        .configure => |configure| {
            // std.log.info("configure={}", .{configure});
            client.request(xdg_surface, .ack_configure, .{ .serial = configure.serial });
            if (!surf.initial_draw) {
                surf.draw();
                // for (surf.subsurfaces.items) |wl_surface|{
                //     const subs = surf.app.surfaces.getPtr(wl_surface).?;
                //     subs.draw();
                // }
                surf.initial_draw = true;
            }
        },
    }
}
fn xdg_toplevel_listener(_: *wlnd.Client, _: xdg.Toplevel, event: xdg.Toplevel.Event, surf: *Surface) void {
    switch (event) {
        .configure => |configure| {
            // std.log.info("configure_top={}", .{configure});
            const configure_size = Size{
                .width = @intCast(configure.width),
                .height = @intCast(configure.height),
            };
            if (configure_size.is_zero()) return;

            const new_size = configure_size.unite(surf.min_size);
            // const old_size = surf.app.layout.get(surf.root, .rect).get_size();
            // if (new_size.is_eql(old_size)) {
            //     std.log.info("old_size={}", .{old_size});
            //     return;
            // }

            surf.size = new_size;

            surf.app.layout.set_size(surf.root, Size.Minmax.tight(new_size));
            surf.schedule_redraw();

            // std.log.info("w: {} h: {}", .{ new_size.width, new_size.height });
        },
        .close => {
            surf.app.client.connection.is_running = false;
        },
        else => {},
    }
}
fn xdg_popup_listener(_: *wlnd.Client, xdg_popup: xdg.Popup, event: xdg.Popup.Event, win: *Surface) void {
    switch (event) {
        .configure => |configure| {
            _ = configure; // autofix
            // std.log.info("popup configure :{}", .{configure});
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
const Rect = @import("paint/Rect.zig");
const Size = @import("paint/Size.zig");

const w = @import("widget.zig");
const WidgetIdx = w.WidgetIdx;

const wlnd = @import("wayland");
const wl = wlnd.wl;
const xdg = wlnd.xdg;
const zwlr = wlnd.zwlr;
const shm = wlnd.shm;
const Surface = @This();
