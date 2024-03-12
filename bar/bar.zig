const std = @import("std");
const mem = std.mem;
const os = std.os;

const wayland = @import("wayland");
const wl = wayland.wl;
const xdg = wayland.xdg;
const zwlr = wayland.zwlr;
const xev = @import("xev");

const font = @import("font/bdf.zig");

const Buffer = wayland.shm.Buffer;
const PaintCtx = @import("paint.zig").PaintCtxU32;
const Rect = @import("paint/Rect.zig");
const Size = @import("paint/Size.zig");
const Point = @import("paint/Point.zig");

pub const std_options = std.Options{
    .log_level = .info,
};

const App = struct {
    client: *wayland.Client,
    shm: ?*wl.Shm = null,
    compositor: ?*wl.Compositor = null,
    wm_base: ?*xdg.WmBase = null,
    layer_shell: ?*zwlr.LayerShellV1 = null,
    seat: ?*wl.Seat = null,
    pointer: ?*wl.Pointer = null,
    running: bool = true,
    font: *font.Font,
    bar: *Bar = undefined,
};

pub const WidgetIdx = enum(u32) {
    _,
};

const WidgetAttrs = struct {
    type: WidgetType,
    rect: Rect = Rect.ZERO,
    flex: u8 = 0,
    hover: bool = false,
    dirty: bool = false,
    children: []const WidgetIdx = &.{},
};

const WidgetType = enum {
    flex,
    button,

    pub fn Type(comptime self: WidgetType) type {
        switch (self) {
            .flex => return @import("widgets/Flex.zig"),
            .button => return @import("widgets/Button.zig"),
        }
    }

    const SizeFn = *const fn (*Layout, WidgetIdx, Size.Minmax) Size;
    pub fn size(self: WidgetType) SizeFn {
        switch (self) {
            inline else => |wt| return wt.Type().size,
        }
    }
    const DrawFn = *const fn (*Layout, WidgetIdx, Rect, PaintCtx) bool;
    pub fn draw(self: WidgetType) DrawFn {
        switch (self) {
            inline else => |wt| return wt.Type().draw,
        }
    }
    const EventFn = *const fn (*Layout, WidgetIdx, Event) void;
    pub fn handle_event(self: WidgetType) EventFn {
        switch (self) {
            inline else => |wt| return wt.Type().handle_event,
        }
    }
};

pub const Layout = struct {
    widgets: std.MultiArrayList(WidgetAttrs) = .{},
    root: WidgetIdx = undefined,
    pointer_position: Point = Point.ZERO,

    pub fn init(self: *Layout, alloc: std.mem.Allocator) !void {
        try self.widgets.ensureTotalCapacity(alloc, 100);
    }
    pub fn add(self: *Layout, widget: WidgetAttrs) WidgetIdx {
        self.widgets.appendAssumeCapacity(widget);
        return @enumFromInt(self.widgets.len - 1);
    }
    pub fn get(
        self: *const Layout,
        idx: WidgetIdx,
        comptime item: std.meta.FieldEnum(WidgetAttrs),
    ) std.meta.FieldType(WidgetAttrs, item) {
        return self.widgets.items(item)[@intFromEnum(idx)];
    }

    pub fn set(
        self: *const Layout,
        idx: WidgetIdx,
        comptime item: std.meta.FieldEnum(WidgetAttrs),
        value: std.meta.FieldType(WidgetAttrs, item),
    ) void {
        self.widgets.items(item)[@intFromEnum(idx)] = value;
    }

    pub fn request_draw(
        self: *const Layout,
        idx: WidgetIdx,
    ) void {
        self.set(idx, .dirty, true);
        const bar = @constCast(@fieldParentPtr(Bar, "layout", self));
        bar.schedule_redraw();
    }

    pub fn draw(layout: *Layout, ctx: PaintCtx) void {
        // std.log.info("CALLING DRAW  {}x{}\n", .{ ctx.width, ctx.height });
        const size = Size.init(ctx.width, ctx.height);
        const widget_size = layout.get(layout.root, .type).size()(
            layout,
            layout.root,
            Size.Minmax.init(size, size),
        );
        std.log.info("size {}\n", .{size});
        layout.widgets.items(.rect)[@intFromEnum(layout.root)] = .{
            .x = 0,
            .y = 0,
            .width = widget_size.width,
            .height = widget_size.height,
        };

        _ = layout.get(layout.root, .type).draw()(layout, layout.root, layout.get(layout.root, .rect), ctx);
    }
};

const Bar = struct {
    ctx: *App,
    wl_surface: *wl.Surface,
    layer_surface: *zwlr.LayerSurfaceV1,
    width: u32,
    height: u32,
    offset: f32,
    last_frame: u32,
    frame_done: bool = true,

    timer: xev.Timer,
    timer_c: xev.Completion = .{},

    layout: Layout = .{},

    fn init(self: *Bar, app: *App) !void {
        const wl_surface = app.compositor.?.create_surface();
        errdefer wl_surface.destroy();
        const layer_surface = app.layer_shell.?.get_layer_surface(wl_surface, null, .top, "");
        errdefer layer_surface.destroy();
        layer_surface.set_listener(*Bar, layer_suface_listener, self);

        layer_surface.set_size(0, 30);
        layer_surface.set_anchor(.{ .top = true, .left = true, .right = true });
        layer_surface.set_exclusive_zone(35);

        self.* = .{
            .ctx = app,
            .wl_surface = wl_surface,
            .layer_surface = layer_surface,
            .width = 0,
            .height = 0,
            .last_frame = 0,
            .offset = 0,
            .timer = try xev.Timer.init(),
        };
        app.bar = self;

        try self.layout.init(app.client.allocator);
        const flex = self.layout.add(.{ .type = .flex });
        const children = try app.client.allocator.alloc(WidgetIdx, 3);
        children[0] = self.layout.add(.{ .type = .button });
        children[1] = self.layout.add(.{ .type = .button, .flex = 1 });
        children[2] = self.layout.add(.{ .type = .button });
        self.layout.set(flex, .children, children);
        self.layout.root = flex;

        wl_surface.commit();
        try app.client.roundtrip();
    }
    fn schedule_redraw(bar: *Bar) void {
        // if (!bar.frame_done) std.log.warn("not done!!!!", .{});
        if (!bar.frame_done) return;
        const frame_cb = bar.wl_surface.frame();
        frame_cb.set_listener(*Bar, frame_listener, bar);
        bar.wl_surface.commit();
        bar.frame_done = false;
    }

    fn timerCallback(
        ud: ?*Bar,
        _: *xev.Loop,
        _: *xev.Completion,
        result: xev.Timer.RunError!void,
    ) xev.CallbackAction {
        _ = result catch unreachable;
        const bar = ud.?;
        const connection = bar.ctx.client.connection;
        if (!bar.frame_done) {
            std.log.info("asd{}", .{connection.recv_c.state()});
            std.log.info("send queue {}", .{connection.out.count});
            return .disarm;
        }
        // bar.schedule_redraw();

        if (connection.send_c.state() == .dead) {
            connection.send();
        } else {
            std.log.info("send not done", .{});
        }
        return .disarm;
    }

    fn layer_suface_listener(layer_suface: *zwlr.LayerSurfaceV1, event: zwlr.LayerSurfaceV1.Event, bar: *Bar) void {
        switch (event) {
            .configure => |configure| {
                layer_suface.ack_configure(configure.serial);

                bar.width = configure.width;
                bar.height = configure.height;

                std.log.info("w: {} h: {}", .{ bar.width, bar.height });

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

    fn frame_listener(cb: *wl.Callback, event: wl.Callback.Event, bar: *Bar) void {
        _ = cb;
        switch (event) {
            .done => |done| {
                const time = done.callback_data;

                if (bar.last_frame != 0) {
                    const elapsed: f32 = @floatFromInt(time - bar.last_frame);
                    bar.offset += elapsed / 1000.0 * 24;
                    std.log.info("zzzz{d:.3}", .{elapsed});
                }

                const buf = Buffer.get(bar.ctx.shm.?, bar.width, bar.height) catch unreachable;
                const ctx = PaintCtx{
                    .buffer = @ptrCast(std.mem.bytesAsSlice(u32, buf.pool.mmap)),
                    .width = buf.width,
                    .height = buf.height,
                };
                bar.layout.draw(ctx);
                bar.wl_surface.attach(buf.wl_buffer, 0, 0);
                bar.wl_surface.damage(0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
                bar.wl_surface.commit();

                bar.last_frame = time;
                bar.frame_done = true;
                // bar.timer.run(&bar.ctx.client.connection.loop, &bar.timer_c, 200, Bar, bar, &timerCallback);
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const client = try wayland.Client.connect(allocator);
    const registry = client.get_registry();

    var context = App{
        .client = client,
        .shm = null,
        .compositor = null,
        .wm_base = null,
        .font = try font.cozette(allocator),
    };

    registry.set_listener(*App, registryListener, &context);
    try client.roundtrip();

    std.debug.assert(context.shm != null);
    std.debug.assert(context.compositor != null);
    std.debug.assert(context.wm_base != null);
    std.debug.assert(context.layer_shell != null);

    var bar: Bar = undefined;
    try bar.init(&context);

    const buf = try Buffer.get(bar.ctx.shm.?, bar.width, bar.height);

    const ctx = PaintCtx{
        .buffer = @ptrCast(std.mem.bytesAsSlice(u32, buf.pool.mmap)),
        .width = buf.width,
        .height = buf.height,
    };
    bar.layout.draw(ctx);
    // draw(&bar);
    bar.wl_surface.attach(buf.wl_buffer, 0, 0);
    bar.wl_surface.commit();
    try client.roundtrip();

    bar.timer.run(&bar.ctx.client.connection.loop, &bar.timer_c, 500, Bar, &bar, &Bar.timerCallback);

    while (context.running) {
        try client.recvEvents();
    }
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

fn draw(bar: *Bar, paint_ctx: PaintCtx) void {
    const Color = @import("paint/Color.zig");

    paint_ctx.fill(.{});
    paint_ctx.fill(.{ .color = Color.NamedColor.lime, .rect = .{
        .x = 500,
        .y = 20,
        .width = 10,
        .height = 10,
    } });
    var time_buf: [65]u8 = undefined;
    const time_slice = std.fmt.bufPrint(&time_buf, "---- Apa,  hello {}", .{std.time.timestamp()}) catch @panic("TODO");
    paint_ctx.text(time_slice, .{ .font = bar.ctx.font, .color = Color.NamedColor.black, .scale = 2 });
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

pub const Event = union(enum) {
    pointer: wl.Pointer.Event,
};

fn pointer_listener(_: *wl.Pointer, event: wl.Pointer.Event, app: *App) void {
    const bar = app.bar;
    switch (event) {
        // .button => |data| { },
        .motion => |ev| {
            bar.layout.pointer_position = Point{ .x = @abs(ev.surface_x.toInt()), .y = @abs(ev.surface_y.toInt()) };
        },
        else => |d| {
            // bar.layout.get(bar.layout.root, .type).handle_event()(&bar.layout, bar.layout.root, Event{ .pointer = event });
            std.log.info("pointer event: {}", .{d});
        },
    }
    for (bar.layout.widgets.items(.rect), 0..) |rect, i| {
        if (rect.contains_point(bar.layout.pointer_position)) {
            bar.layout.get(@enumFromInt(i), .type).handle_event()(&bar.layout, @enumFromInt(i), Event{ .pointer = event });
            bar.layout.set(@enumFromInt(i), .hover, true);
        } else {
            bar.layout.set(@enumFromInt(i), .hover, false);
        }
    }
}
