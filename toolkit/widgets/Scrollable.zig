const std = @import("std");

const tk = @import("../toolkit.zig");
const PaintCtx = tk.PaintCtx;
const widget = tk.widget;
const Layout = widget.Layout;
const WidgetIdx = widget.WidgetIdx;

widget: WidgetIdx,
offset: i32 = 22,

pub fn draw(layout: *Layout, idx: WidgetIdx, rect: tk.Rect, paint_ctx: PaintCtx) bool {
    const font = layout.get_app().font;

    std.log.info("paint_ctx.clip={}", .{paint_ctx.clip});
    paint_ctx.text("Hello", .{ .rect = rect, .font = font, .color = .blue });
    paint_ctx.fill(.{ .rect = rect, .color = .teal });
    // std.log.info("btn {} hover {}", .{ @intFromEnum(idx), hover });

    const self = layout.data(idx, @This());
    // _=layout.call(self.widget, .draw, .{rect,paint_ctx});
    const abs_rect = layout.absolute_rect(idx);

    var iter = layout.child_iterator(self.widget);
    while (iter.next()) |idxx| {
        // defer std.log.info("it.depth={}", .{iter.depth});
        const rectx = layout.absolute_rect(idxx).translated(
            abs_rect.x,
            abs_rect.y,
        ).translated(0, self.offset);
        _ = layout.call(idxx, .draw, .{ rectx, paint_ctx });
    }

    return true;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
    layout.request_draw(idx);
    const self = layout.data(idx, @This());
    switch (event) {
        .pointer => |ev| switch (ev) {
            .axis => |ev2| {
                std.log.info("ev2={}", .{ev2});
                self.offset +|= ev2.value;
            },
            else => {},
        },
        else => {},
    }
    std.log.info("event: {}", .{event});
}

pub fn size(layout: *Layout, idx: WidgetIdx, minmax: tk.Size.Minmax) tk.Size {
    std.log.info("size", .{});
    const self = layout.data(idx, @This());
    const child = self.widget;
    const c_size = layout.call(child, .size, .{minmax});
    _ = c_size; // autofix
    // _ = c_size; // autofix
    // layout.set(children[0], .rect, c_size.to_rect());
    layout.set(child, .rect, minmax.max.to_rect());
    // return c_size;
    return minmax.max;

    // return .{ .width = 60, .height = 20 };
}
