const std = @import("std");
const w = @import("../widget.zig");
const Layout = w.Layout;
const WidgetIdx = w.WidgetIdx;

const PaintCtx = @import("../paint.zig").PaintCtxU32;
const Event = @import("../event.zig").Event;
const Rect = @import("../paint/Rect.zig");
const Size = @import("../paint/Size.zig");

on_click_widx: WidgetIdx,
on_click_event: u8,

pub fn draw(layout: *Layout, idx: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {
    const hover = layout.get(idx, .hover);
    const pressed = layout.get(idx, .pressed);
    paint_ctx.panel(.{ .rect = rect, .hover = hover, .press = pressed });

    return true;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: Event) void {
    layout.request_draw(idx);
    std.log.info("event: {}", .{event});
    switch (event.pointer) {
        .enter => {
            layout.set_cursor_shape(.pointer);
        },
        // .leave => {
        //     layout.set_cursor_shape(.default);
        // },
        else => {
            std.log.info("event: {}", .{event});
        },
    }
}

pub fn size(_: *Layout, _: WidgetIdx, _: Size.Minmax) Size {
    return Size{ .width = 60, .height = 20 };
}
