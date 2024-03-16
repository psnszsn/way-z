const Button = @This();
const w = @import("../widget.zig");
const Layout = w.Layout;
const WidgetIdx = w.WidgetIdx;

const PaintCtx = @import("../paint.zig").PaintCtxU32;
const Event = @import("../event.zig").Event;
const Rect = @import("../paint/Rect.zig");
const Size = @import("../paint/Size.zig");

is_active: bool = false,
is_hover: bool = false,

var g = Button{};

pub fn draw(layout: *Layout, idx: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {
    const hover = layout.get(idx, .hover);
    const pressed = layout.get(idx, .pressed);
    // paint_ctx.fill(.{ .color = Color.NamedColor.orange, .rect = rect });
    paint_ctx.panel(.{ .rect = rect, .hover = hover, .press = pressed });

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
    return Size{ .width = 60, .height = 20 };
}
