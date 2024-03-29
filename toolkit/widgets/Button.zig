const std = @import("std");

const tk = @import("../toolkit.zig");
const PaintCtx = tk.PaintCtx;
const widget = tk.widget;
const Layout = widget.Layout;
const WidgetIdx = widget.WidgetIdx;

on_click_widx: ?WidgetIdx = null,
on_click_event: u8 = 0,

pub const Event = union(enum) { click: void };

pub fn draw(layout: *Layout, idx: WidgetIdx, rect: tk.Rect, paint_ctx: PaintCtx) bool {
    const hover = layout.get(idx, .hover);
    const pressed = layout.get(idx, .pressed);

    paint_ctx.panel(.{ .rect = rect, .hover = hover, .press = pressed });
    // std.log.info("btn {} hover {}", .{ @intFromEnum(idx), hover });

    return true;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
    layout.request_draw(idx);
    std.log.info("event: {}", .{event});
    switch (event.pointer) {
        .enter => {
            layout.set_cursor_shape(.pointer);
        },
        // .leave => {
        //     layout.set_cursor_shape(.default);
        // },
        .button => |b| {
            if (b.state == .released)
                layout.emit_event(idx, &Event.click);
        },
        else => {
            // std.log.info("event: {any}", .{event});
        },
    }
}

pub fn size(_: *Layout, _: WidgetIdx, _: tk.Size.Minmax) tk.Size {
    return .{ .width = 60, .height = 20 };
}
