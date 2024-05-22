const std = @import("std");

const tk = @import("../toolkit.zig");
const PaintCtx = tk.PaintCtx;
const widget = tk.widget;
const Layout = widget.Layout;
const WidgetIdx = widget.WidgetIdx;

widget: WidgetIdx,
offset: u32 = 0,

pub fn draw(layout: *Layout, idx: WidgetIdx, rect: tk.Rect, paint_ctx: PaintCtx) bool {
    const font = layout.get_app().font;
    const self = layout.data(idx, @This());

    paint_ctx.fill(.{ .rect = rect, .color = .teal });
    paint_ctx.text("Hello", .{ .rect = rect, .font = font, .color = .blue });

    paint_ctx.fill(.{ .rect = .{
        .x = rect.right() - 16,
        .y = rect.y,
        .width = 16,
        .height = rect.height,
    }, .color = .gainsboro });

    const scrubber_height: u32 = @intFromFloat(visible_fraction(layout, idx) * @as(f32, @floatFromInt(rect.height)));
    const scrubber_range = rect.height - scrubber_height;
    const max_off = max_offset(layout, idx);
    const scrubber_pos = if (max_off == 0) 0 else scrubber_range * self.offset / max_off;
    paint_ctx.fill(.{ .rect = .{
        .x = rect.right() - 16,
        .y = rect.y + scrubber_pos,
        .width = 16,
        .height = scrubber_height,
    }, .color = .indianred });

    std.debug.assert(rect.height != 0);

    // _=layout.call(self.widget, .draw, .{rect,paint_ctx});
    const abs_rect = layout.absolute_rect(idx);

    var iter = layout.child_iterator(self.widget);
    while (iter.next()) |idxx| {
        const offset_i64: i64 = @intCast(self.offset);
        const rectx = layout.absolute_rect(idxx)
            .translated(abs_rect.x, abs_rect.y)
            .translated(0, -offset_i64);
        _ = layout.call(idxx, .draw, .{ rectx, paint_ctx });
    }

    return true;
}
pub fn visible_fraction(layout: *Layout, idx: WidgetIdx) f32 {
    const self = layout.data(idx, @This());
    const rect = layout.get(idx, .rect);
    const content_rect = layout.get(self.widget, .rect);
    const visible: f32 = @floatFromInt(rect.height);
    const total: f32 = @floatFromInt(content_rect.height);
    if (visible >= total) return 1;

    return visible / total;
}

pub fn max_offset(layout: *Layout, idx: WidgetIdx) u32 {
    const self = layout.data(idx, @This());
    const rect = layout.get(idx, .rect);
    const content_rect = layout.get(self.widget, .rect);
    const max = content_rect.height -| rect.height;
    return max;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
    layout.request_draw(idx);
    const self = layout.data(idx, @This());
    switch (event) {
        .pointer => |ev| switch (ev) {
            .axis => |ev2| {
                const max = max_offset(layout, idx);
                if (ev2.value < 0) self.offset -|= @abs(ev2.value) else {
                    self.offset += @abs(ev2.value);
                    self.offset = std.math.clamp(self.offset, 0, max);
                }
            },
            else => {},
        },
        else => {},
    }
}

pub fn size(layout: *Layout, idx: WidgetIdx, minmax: tk.Size.Minmax) tk.Size {
    const self = layout.data(idx, @This());
    const child = self.widget;
    const c_size = layout.call(child, .size, .{minmax});
    // _ = c_size; // autofix
    // layout.set(children[0], .rect, c_size.to_rect());
    layout.set(child, .rect, c_size.to_rect());
    // return c_size;
    // return minmax.max;
    const min: tk.Size = .{ .width = 60, .height = 20 };
    return min.unite(minmax.max);
}
