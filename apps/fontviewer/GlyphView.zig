const scale = 10;
code_point: u21 = 'b',
font: *tk.Font,

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
    const self = layout.data(idx, FontView);
    _ = self; // autofix

    switch (event) {
        else => {},
    }
}

pub fn draw(layout: *Layout, idx: WidgetIdx, paint_ctx: tk.PaintCtx) bool {
    paint_ctx.fill(.{ .color = .pink });
    const self = layout.data(idx, FontView);
    const bitmap = self.font.glyphBitmap(self.code_point);
    const rect = paint_ctx.clip;

    for (0..self.font.glyph_height) |_y| {
        const y: u8 = @intCast(_y);
        for (0..bitmap.width) |_x| {
            const x: u8 = @intCast(_x);
            const pixel_rect = tk.Rect{
                .x = rect.x + x * scale,
                .y = rect.y + y * scale,
                .width = scale,
                .height = scale,
            };
            const c: tk.Color = if (bitmap.bitAt(x, y)) .black else .white;
            paint_ctx.with_clip(pixel_rect).fill(.{ .color = c });
        }
    }

    return true;
}

pub fn size(layout: *Layout, idx: WidgetIdx, _: tk.Size.Minmax) tk.Size {
    const font = layout.data(idx, FontView).font;
    return .{
        .width = font.glyph_width * scale,
        .height = font.glyph_height * scale,
    };
}

const FontView = @This();

const tk = @import("toolkit");
const widget = tk.widget;
const Layout = widget.Layout;
const WidgetIdx = widget.WidgetIdx;
