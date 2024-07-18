const letter_padding = 2;
columns: u16,
selected_code_point: u21 = 'a',
selected_range: u32 = 0,
font: *Font,

pub const Event = union(enum) {
    code_point_clicked: u21,
};

fn rows(fm: *const FontMap) u16 {
    return 256 / fm.columns;
}

fn getOuterRect(font: *const Font, cols: u16, code_point: u21) Rect {
    const n = code_point % 256;
    const row_ = n / cols;
    const column_ = n % cols;

    return Rect{
        .x = column_ * (font.glyph_width + letter_padding),
        .y = row_ * (font.glyph_height + letter_padding),
        .width = font.glyph_width + letter_padding,
        .height = font.glyph_height + letter_padding,
    };
}

pub fn draw(layout: *Layout, idx: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {
    // std.log.warn("size:::: {}", .{paint_ctx.rect()});
    const self = layout.data(idx, FontMap);
    const font = self.font;

    paint_ctx.fill(rect, .{ .color = .white });

    for (0..256) |glyph_n| {
        const glyph: u21 = @intCast(glyph_n + self.selected_range * 256);
        const bitmap = font.glyphBitmap(glyph);
        var glyph_rect = getOuterRect(font, self.columns, glyph).relative_to(rect);
        if (glyph == self.selected_code_point) {
            paint_ctx.fill(glyph_rect, .{ .color = .red });
        }
        glyph_rect.shrink_uniform(letter_padding / 2);

        glyph_rect.x = glyph_rect.get_center().x - bitmap.width / 2;
        _ = paint_ctx.char(glyph, glyph_rect.pos(), .{ .font = font, .color = .black });
    }

    return true;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
    const self = layout.data(idx, FontMap);
    const font = layout.get_window().app.font;
    switch (event.pointer) {
        .enter => layout.set_cursor_shape(.pointer),
        .button => |btn| {
            for (0..256) |glyph_n| {
                const glyph: u21 = @intCast(glyph_n + self.selected_range * 256);
                var outer_rect = getOuterRect(font, self.columns, glyph);
                if (outer_rect.contains_point(btn.pos)) {
                    self.selected_code_point = glyph;
                    std.log.info("glyph={}", .{glyph});
                    std.log.info("pos={}", .{btn.pos});
                    layout.request_draw(idx);
                    // layout.emit_event(idx, &Event{ .code_point_clicked = glyph });
                    break;
                }
            }
        },
        else => {},
    }
}

pub fn size(layout: *Layout, idx: WidgetIdx, _: Size.Minmax) Size {
    const self = layout.data(idx, FontMap);
    const font = self.font;
    const width = self.columns * (font.glyph_width + letter_padding);
    const height = self.rows() * (font.glyph_height + letter_padding);
    return Size{ .width = width, .height = height };
}

const FontMap = @This();

const tk = @import("toolkit");
const PaintCtx = tk.PaintCtx;
const widget = tk.widget;
const Layout = widget.Layout;
const WidgetIdx = widget.WidgetIdx;

const Font = tk.Font;
const Rect = tk.Rect;
const Size = tk.Size;
const std = @import("std");
