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

        wl_surface.commit();
        try app.client.roundtrip();
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
        const frame_cb = bar.wl_surface.frame();
        frame_cb.set_listener(*Bar, frame_listener, bar);
        bar.wl_surface.commit();
        bar.frame_done = false;

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
                draw(bar, buf.pool.mmap, bar.width, bar.height, bar.offset);
                bar.wl_surface.attach(buf.wl_buffer, 0, 0);
                bar.wl_surface.damage(0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
                bar.wl_surface.commit();

                bar.last_frame = time;
                bar.frame_done = true;
                bar.timer.run(&bar.ctx.client.connection.loop, &bar.timer_c, 20, Bar, bar, &timerCallback);
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
    draw(&bar, buf.pool.mmap, bar.width, bar.height, 0);
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

fn draw(bar: *Bar, buf: []align(4096) u8, width: u32, height: u32, _offset: f32) void {
    _ = _offset; // autofix
    const data_u32: []u32 = std.mem.bytesAsSlice(u32, buf);

    @memset(data_u32, 0xffffff);

    const Color = @import("paint/Color.zig");
    const paint_ctx = @import("paint.zig").PaintCtxU32{
        .buffer = @ptrCast(data_u32),
        .width = width,
        .height = height,
    };

    paint_ctx.fill(.{});
    paint_ctx.fill(.{ .color = Color.NamedColor.lime, .rect = .{
        .x = 500,
        .y = 20,
        .width = 10,
        .height = 10,
    } });
    var time_buf: [65]u8 = undefined;
    const time_slice = std.fmt.bufPrint(&time_buf, "---- Apa,  hello {}", .{std.time.timestamp()}) catch @panic("TODO");
    paint_ctx.draw_text(time_slice, .{ .font = bar.ctx.font, .color = Color.NamedColor.black, .scale = 2 });
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

fn pointer_listener(pointer: *wl.Pointer, event: wl.Pointer.Event, app: *App) void {
    _ = pointer; // autofix
    _ = app; // autofix
    switch (event) {
        // .button => |data| { },
        .motion => {},
        else => |d| {
            std.log.info("pointer event: {}", .{d});
        },
    }
}
