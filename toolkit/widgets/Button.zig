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
    // std.log.info("event: {}", .{event});
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

pub fn size(layout: *Layout, idx: WidgetIdx, minmax: tk.Size.Minmax) tk.Size {
    _ = minmax; // autofix
    const children = layout.get(idx, .children);
    const rect = layout.get(idx, .rect);
    std.log.info("minmax: {}", .{rect});
    std.debug.assert(children.len <= 1);

    if (children.len == 1) {
        const child_rect = layout.get_ptr(children[0], .rect);
        child_rect.set_origin(.{ .x = 5, .y = 5 });

        // layout.set(children[0], .rect, rect.shrunken_uniform(3));
    }

    return .{ .width = 60, .height = 20 };
}
