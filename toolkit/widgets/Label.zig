const std = @import("std");

const tk = @import("../toolkit.zig");
const PaintCtx = tk.PaintCtx;
const widget = tk.widget;
const Layout = widget.Layout;
const WidgetIdx = widget.WidgetIdx;

pub fn draw(layout: *Layout, idx: WidgetIdx, paint_ctx: PaintCtx) bool {
    _ = idx; // autofix
    const font = layout.get_window().app.font;

    paint_ctx.text("Hello", .{ .font = font, .color = .blue });
    // std.log.info("btn {} hover {}", .{ @intFromEnum(idx), hover });

    return true;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
    layout.request_draw(idx);
    std.log.info("event: {}", .{event});
}

pub fn size(_: *Layout, _: WidgetIdx, _: tk.Size.Minmax) tk.Size {
    return .{ .width = 60, .height = 20 };
}
