pub const extra_w = .{
    .log_level = FontView,
};

pub const std_options = std.Options{
    .log_level = .info,
};

pub const FontView = struct {
    const Self = @This();
    const scale = 10;
    font: *Font,
    code_point: u21,

    pub fn handle_event(_: *Layout, _: WidgetIdx, _: Event) void {}

    pub fn draw(layout: *Layout, _: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {
        paint_ctx.fill(.{ .color = Color.NamedColor.pink, .rect = rect });

        const font = layout.get_window().app.font;
        const bitmap = layout.get_window().app.font.glyphBitmap('a');

        for (0..font.glyph_height) |y| {
            for (0..bitmap.width) |x| {
                const pixel_rect = Rect{
                    .x = rect.x + x * scale,
                    .y = rect.y + y * scale,
                    .width = scale,
                    .height = scale,
                };
                const c = if (bitmap.bitAt(x, y)) Color.NamedColor.black else Color.NamedColor.white;
                paint_ctx.fill(.{ .rect = pixel_rect, .color = c });
            }
        }

        return true;
    }

    pub fn size(layout: *Layout, _: WidgetIdx, _: Size.Minmax) Size {
        const font = layout.get_window().app.font;
        return Size{
            .width = font.glyph_width * scale,
            .height = font.glyph_height * scale,
        };
    }
};
pub const FontMap = struct {
    const Self = @This();
    const letter_padding = 2;
    columns: usize,
    selected_code_point: u21,
    // onGlyphSelected: ?Callback = null,

    var self = FontMap{
        .columns = 32,
        .selected_code_point = 'a',
    };

    fn rows(fm: *const FontMap) usize {
        return 256 / fm.columns;
    }

    fn getOuterRect(font: *const Font, cols: usize, glyph: u8) Rect {
        const row_ = glyph / cols;
        const column_ = glyph % cols;

        return Rect{
            .x = column_ * (font.glyph_width + letter_padding),
            .y = row_ * (font.glyph_height + letter_padding),
            .width = font.glyph_width + letter_padding,
            .height = font.glyph_height + letter_padding,
        };
    }

    pub fn draw(layout: *Layout, idx: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {
        std.log.warn("size:::: {}", .{paint_ctx.rect()});
        _ = idx; // autofix
        const font = layout.get_window().app.font;

        paint_ctx.fill(.{ .color = Color.NamedColor.white, .rect = rect });

        for (0..256) |_glyph| {
            const glyph: u8 = @intCast(_glyph);
            const bitmap = font.glyphBitmap(glyph);
            var outer_rect = getOuterRect(font, self.columns, glyph).relative_to(rect);
            if (glyph == self.selected_code_point) {
                paint_ctx.fill(.{ .rect = outer_rect, .color = Color.NamedColor.red });
            }
            outer_rect.shrinkUniform(letter_padding / 2);

            outer_rect.x = outer_rect.getCenter().x - bitmap.width / 2;
            _ = paint_ctx.char(glyph, .{ .rect = outer_rect, .font = font, .color = Color.NamedColor.black });
        }

        return true;
    }

    pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: Event) void {
        const font = layout.get_window().app.font;
        const rect = layout.get(idx, .rect);
        switch (event.pointer) {
            .button => |_| {
                for (0..256) |_glyph| {
                    const glyph: u8 = @intCast(_glyph);
                    var outer_rect = getOuterRect(font, self.columns, glyph).relative_to(rect);
                    if (outer_rect.contains(layout.pointer_position.x, layout.pointer_position.y)) {
                        self.selected_code_point = glyph;
                        layout.request_draw(idx);
                        // self.onGlyphSelected.?(self);
                        // self.onGlyphSelected.?.call();
                        break;
                    }
                }
            },
            else => {},
        }
    }

    pub fn size(layout: *Layout, _: WidgetIdx, _: Size.Minmax) Size {
        const font = layout.get_window().app.font;
        const width = self.columns * (font.glyph_width + letter_padding);
        const height = self.rows() * (font.glyph_height + letter_padding);
        return Size{ .width = width, .height = height };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var app = try App.new(allocator);
    var bar = try app.new_window(.xdg_shell);
    _ = &bar; // autofix

    try bar.layout.init(app.client.allocator);
    const flex = bar.layout.add(.{ .type = .flex });
    const btn = bar.layout.add(.{ .type = .button });
    const font_map = bar.layout.add(.{ .type = .font_map });
    const font_view = bar.layout.add(.{ .type = .font_view });
    // children[2] = bar.layout.add(.{ .type = .button });
    bar.layout.set(flex, .children, &.{ btn, font_map, font_view });
    bar.set_root_widget(flex);

    bar.draw();

    try app.client.recvEvents();
}

const std = @import("std");
const wayland = @import("wayland");
const Buffer = wayland.shm.Buffer;
const PaintCtx = @import("paint.zig").PaintCtxU32;
const App = @import("App.zig");
const widget = @import("widget.zig");
const Font = @import("./font/bdf.zig").Font;

const w = @import("widget.zig");
const Layout = w.Layout;
const WidgetIdx = w.WidgetIdx;

const Event = @import("event.zig").Event;
const Rect = @import("paint/Rect.zig");
const Size = @import("paint/Size.zig");
const Color = @import("paint/Color.zig");
