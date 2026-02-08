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

fn cellRect(cols: u16, nrows: u16, code_point: u21, area_w: u31, area_h: u31) Rect {
    const n = code_point % 256;
    const row_: u31 = @intCast(n / cols);
    const column_: u31 = @intCast(n % cols);

    const cell_w = area_w / cols;
    const cell_h = area_h / nrows;

    return Rect{
        .x = column_ * cell_w,
        .y = row_ * cell_h,
        .width = cell_w,
        .height = cell_h,
    };
}

pub fn draw(layout: *Layout, idx: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {
    const self = layout.data(idx, FontMap);
    const font = self.font;
    const font_scale = paint_ctx.fontScale();
    const nrows = self.rows();

    paint_ctx.fill(rect, .{ .color = .white });

    for (0..256) |glyph_n| {
        const glyph: u21 = @intCast(glyph_n + self.selected_range * 256);
        const bitmap = font.glyphBitmap(glyph);
        var glyph_rect = cellRect(self.columns, nrows, glyph, rect.width, rect.height).relative_to(rect);
        if (glyph == self.selected_code_point) {
            paint_ctx.fill(glyph_rect, .{ .color = .red });
        }

        // Center the glyph in the cell
        const gw = @as(i32, bitmap.width) * font_scale;
        const gh = @as(i32, font.glyph_height) * font_scale;
        const cx = glyph_rect.x + @divTrunc(@as(i32, glyph_rect.width) - gw, 2);
        const cy = glyph_rect.y + @divTrunc(@as(i32, glyph_rect.height) - gh, 2);
        _ = paint_ctx.char(glyph, .{ .x = cx, .y = cy }, .{ .font = font, .color = .black });
    }

    return true;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
    const self = layout.data(idx, FontMap);
    const scale_120 = layout.get_window().scale_120;
    const nrows = self.rows();
    // Get the physical pixel size of this widget's rect
    const phys_rect = layout.get(idx, .rect).scaled(scale_120);
    switch (event.pointer) {
        .enter => layout.set_cursor_shape(.pointer),
        .button => |btn| {
            const scaled_pos = btn.pos.scaled(scale_120);
            for (0..256) |glyph_n| {
                const glyph: u21 = @intCast(glyph_n + self.selected_range * 256);
                const cell = cellRect(self.columns, nrows, glyph, phys_rect.width, phys_rect.height);
                if (cell.contains_point(scaled_pos)) {
                    self.selected_code_point = glyph;
                    layout.request_draw(idx);
                    layout.emit_event(idx, &Event{ .code_point_clicked = glyph });
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
