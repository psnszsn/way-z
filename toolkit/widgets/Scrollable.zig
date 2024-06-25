const std = @import("std");

const tk = @import("../toolkit.zig");
const PaintCtx = tk.PaintCtx;
const widget = tk.widget;
const Layout = widget.Layout;
const WidgetIdx = widget.WidgetIdx;

const thumb_btn = 0;

content: WidgetIdx,
children: [1]WidgetIdx,
offset: u32 = 0,

pub const InitOpts = struct {
    content: WidgetIdx,
};
pub fn init(layout: *Layout, idx: WidgetIdx, opts: InitOpts) void {
    const self = layout.data(idx, @This());
    self.offset = 0;
    self.content = opts.content;
    self.children[thumb_btn] = layout.add2(.button, .{});
    layout.set(idx, .children, self.children[0..]);
}

pub fn draw(layout: *Layout, idx: WidgetIdx, paint_ctx: PaintCtx) bool {
    const font = layout.get_app().font;
    const self = layout.data(idx, @This());

    paint_ctx.fill(.{ .color = .teal });
    paint_ctx.text("Hello", .{ .font = font, .color = .blue });
    const rect = paint_ctx.clip;

    {
        const r = .{
            .x = rect.right() - 16,
            .y = rect.y,
            .width = 16,
            .height = rect.height,
        };
        // paint_ctx.with_clip(r).fill(.{ .color = .gainsboro });
        paint_ctx.with_clip(r).fill(.{ .color = .olive });
    }

    {
        // const content_rect = layout.get(self.content, .rect);
        // var r = thumb_rect(@floatFromInt(paint_ctx.clip.height), @floatFromInt(content_rect.height), self.offset);
        // r.x = paint_ctx.clip.right() - 16;
        // r.y += paint_ctx.clip.y;
        //
        // paint_ctx.with_clip(r).fill(.{ .color = .indianred });
    }

    std.debug.assert(rect.height != 0);

    const abs_rect = layout.absolute_rect(idx);
    var iter = layout.child_iterator(self.content);
    while (iter.next()) |idxx| {
        const offset_i64: i64 = @intCast(self.offset);
        const rectx = layout.absolute_rect(idxx)
            .translated(abs_rect.x, abs_rect.y)
            .translated(0, -offset_i64);
        // .intersected(paint_ctx.clip);

        _ = layout.call(idxx, .draw, .{paint_ctx.with_clip(rectx)});
    }

    return true;
}
// pub fn visible_fraction(layout: *Layout, idx: WidgetIdx) f32 {
//     const self = layout.data(idx, @This());
//     const rect = layout.get(idx, .rect);
//     const content_rect = layout.get(self.content, .rect);
//     const visible: f32 = @floatFromInt(rect.height);
//     const total: f32 = @floatFromInt(content_rect.height);
//     if (visible >= total) return 1;
//
//     return visible / total;
// }
pub fn thumb_rect(visible: f32, total: f32, offset: u32) tk.Rect {
    const visible_fraction = if (visible >= total) 1 else visible / total;
    const scrubber_height: u32 = @intFromFloat(visible_fraction *
        visible);
    const scrubber_range = @as(u32, @intFromFloat(visible)) - scrubber_height;
    const max_off: u32 = @intFromFloat(total - visible);
    const scrubber_pos = if (max_off == 0) 0 else scrubber_range * offset / max_off;

    const r: tk.Rect = .{
        .x = 0,
        .y = scrubber_pos,
        .width = 16,
        .height = scrubber_height,
    };
    return r;
}

pub fn max_offset(layout: *Layout, idx: WidgetIdx) u32 {
    const self = layout.data(idx, @This());
    const rect = layout.get(idx, .rect);
    const content_rect = layout.get(self.content, .rect);
    const max = content_rect.height -| rect.height;
    return max;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
    layout.request_draw(idx);
    const self = layout.data(idx, @This());
    switch (event) {
        .pointer => |ev| switch (ev) {
            .axis => |ev2| {
                if (ev2.value < 0) self.offset -|= @abs(ev2.value) else {
                    self.offset += @abs(ev2.value);
                    self.offset = @min(self.offset, max_offset(layout, idx));
                }
                layout.get_window().re_size();
            },
            else => {},
        },
        else => {},
    }
}

pub fn size(layout: *Layout, idx: WidgetIdx, minmax: tk.Size.Minmax) tk.Size {
    const self = layout.data(idx, @This());
    self.offset = @min(self.offset, max_offset(layout, idx));

    layout.set_size(self.content, minmax);

    const min: tk.Size = .{ .width = 60, .height = 20 };
    const rsize = min.unite(minmax.max);
    std.log.info("minmax={}", .{minmax});
    {
        const content_rect = layout.get(self.content, .rect);
        const r = thumb_rect(@floatFromInt(rsize.height), @floatFromInt(content_rect.height), self.offset)
            .translated(rsize.width - 16, 0);

        layout.set(self.children[thumb_btn], .rect, r);
    }
    return rsize;
}
