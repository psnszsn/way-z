const Self = @This();
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

pub fn draw(layout: *Layout, idx: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {
    _ = layout; // autofix
    _ = idx; // autofix

    // paint_ctx.fill(.{ .color = Color.NamedColor.orange, .rect = rect });
    paint_ctx.panel(.{ .rect = rect });

    // std.debug.print("BTN CLIP{}\n", .{painter.clip});

    // buffer.drawBorder();

    // const c2 = if (self.is_active) NamedColor.red else Color.fromString("blue");

    // buffer.rect.shrinkUniform(1);
    // buffer.fillColor(c2);

    return true;
}

pub fn handle_event(_: *Layout, idx: WidgetIdx, _: Event) void {
    _ = idx; // autofix
}

pub fn size(_: *Layout, _: WidgetIdx, _: Size.Minmax) Size {
    return Size{ .width = 100, .height = 20 };
}
