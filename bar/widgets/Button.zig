const Button = @This();
const std = @import("std");
const Layout = @import("../bar.zig").Layout;

const PaintCtx = @import("../paint.zig").PaintCtxU32;
const WidgetIdx = @import("../bar.zig").WidgetIdx;
const Event = @import("../bar.zig").Event;
const Rect = @import("../paint/Rect.zig");
const Size = @import("../paint/Size.zig");
const Color = @import("../paint/Color.zig");

is_active: bool = false,
is_hover: bool = false,

var g = Button{};

pub fn draw(layout: *Layout, idx: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {
    const hover = layout.get(idx, .hover);
    // paint_ctx.fill(.{ .color = Color.NamedColor.orange, .rect = rect });
    paint_ctx.panel(.{ .rect = rect, .hover = hover });

    // std.debug.print("BTN CLIP{}\n", .{painter.clip});

    // buffer.drawBorder();

    // const c2 = if (self.is_active) NamedColor.red else Color.fromString("blue");

    // buffer.rect.shrinkUniform(1);
    // buffer.fillColor(c2);

    return true;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: Event) void {
    layout.request_draw(idx);
    switch (event.pointer) {
        else => {},
    }
}

pub fn size(_: *Layout, _: WidgetIdx, _: Size.Minmax) Size {
    return Size{ .width = 100, .height = 20 };
}
