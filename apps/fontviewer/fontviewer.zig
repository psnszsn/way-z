pub const widget_types = .{
    .font_view = FontView,
    .font_map = FontMap,
};

pub const std_options = std.Options{
    .log_level = .info,
};

pub const FontView = struct {
    const scale = 10;
    code_point: u21 = 'b',
    font: *Font,

    pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
        const self = layout.data(idx, FontView);

        switch (event) {
            .custom => |cev| {
                const e = std.mem.bytesAsValue(FontMap.Event, &cev.data);
                self.code_point = e.code_point_selected;
                layout.request_draw(idx);
            },
            else => {},
        }
    }

    pub fn draw(layout: *Layout, idx: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {
        paint_ctx.fill(.{ .color = .pink, .rect = rect });
        const self = layout.data(idx, FontView);
        const bitmap = self.font.glyphBitmap(self.code_point);

        for (0..self.font.glyph_height) |_y| {
            const y: u8 = @intCast(_y);
            for (0..bitmap.width) |_x| {
                const x: u8 = @intCast(_x);
                const pixel_rect = Rect{
                    .x = rect.x + x * scale,
                    .y = rect.y + y * scale,
                    .width = scale,
                    .height = scale,
                };
                const c = if (bitmap.bitAt(x, y)) Color.black else Color.white;
                paint_ctx.fill(.{ .rect = pixel_rect, .color = c });
            }
        }

        return true;
    }

    pub fn size(layout: *Layout, idx: WidgetIdx, _: Size.Minmax) Size {
        const font = layout.data(idx, FontView).font;
        return Size{
            .width = font.glyph_width * scale,
            .height = font.glyph_height * scale,
        };
    }
};
pub const FontMap = struct {
    const letter_padding = 2;
    columns: u16,
    selected_code_point: u21 = 'a',
    font: *Font,

    subscriber: WidgetIdx,

    const Event = union(enum) {
        code_point_selected: u21,
    };

    fn rows(fm: *const FontMap) u16 {
        return 256 / fm.columns;
    }

    fn getOuterRect(font: *const Font, cols: u16, glyph: u8) Rect {
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
        // std.log.warn("size:::: {}", .{paint_ctx.rect()});
        const self = layout.data(idx, FontMap);
        const font = self.font;

        paint_ctx.fill(.{ .color = .white, .rect = rect });

        for (0..256) |_glyph| {
            const glyph: u8 = @intCast(_glyph);
            const bitmap = font.glyphBitmap(glyph);
            var outer_rect = getOuterRect(font, self.columns, glyph).relative_to(rect);
            if (glyph == self.selected_code_point) {
                paint_ctx.fill(.{ .rect = outer_rect, .color = .red });
            }
            outer_rect.shrinkUniform(letter_padding / 2);

            outer_rect.x = outer_rect.get_center().x - bitmap.width / 2;
            _ = paint_ctx.char(glyph, .{ .rect = outer_rect, .font = font, .color = .black });
        }

        return true;
    }

    pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: tk.Event) void {
        const self = layout.data(idx, FontMap);
        const font = layout.get_window().app.font;
        const rect = layout.get(idx, .rect);
        const app = layout.get_app();
        switch (event.pointer) {
            .enter => layout.set_cursor_shape(.pointer),
            .button => |_| {
                for (0..256) |_glyph| {
                    const glyph: u8 = @intCast(_glyph);
                    var outer_rect = getOuterRect(font, self.columns, glyph).relative_to(rect);
                    if (outer_rect.contains(app.pointer_position.x, app.pointer_position.y)) {
                        self.selected_code_point = glyph;
                        std.log.info("selected {}", .{glyph});
                        layout.request_draw(idx);
                        // self.onGlyphSelected.?(self);
                        // self.onGlyphSelected.?.call();
                        const E = Event{ .code_point_selected = glyph };
                        layout.call(self.subscriber, .handle_event, .{tk.Event{ .custom = .{ .emitter = idx, .data = std.mem.toBytes(E) } }});
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
};

pub fn contextmenu(layout: *Layout) !void {
    _ = layout; // autofix
    // const popup_btn = layout.add2(.button, .{});
    // layout.set_handler(popup_btn, handler);
}
const PopupHandler = struct {
    parent: *App.Surface,
    widget: WidgetIdx,
    wl_surface: ?wlnd.wl.Surface,
    pub fn handle_event(layout: *Layout, idx: WidgetIdx, ev: *const anyopaque, data: *PopupHandler) void {
        _ = ev; // autofix
        switch (layout.get(idx, .type)) {
            .button => {
                // const event = widget.WidgetEvent(.button);
                // _ = event; // autofix
                const app = layout.get_app();
                if (data.wl_surface) |s| {
                    const surface = app.find_wl_surface(s);
                    if (surface) |sf| {
                        sf.destroy();
                        return;
                    }
                }
                const rect = layout.get(idx, .rect);
                const popup = app.new_popup(data.parent, data.widget, rect) catch unreachable;
                data.wl_surface = popup.wl_surface;
            },
            else => unreachable,
        }

        // std.log.info("data {?}", .{surface});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try App.new(allocator);
    defer app.deinit();

    const layout = &app.layout;
    try layout.init(app.client.allocator);

    var handler: PopupHandler = undefined;

    const main_widget = b: {
        const flex = layout.add2(.flex, .{ .orientation = .vertical });
        const menu_bar = c: {
            const btn = layout.add2(.button, .{});
            const btn2 = layout.add2(.button, .{});

            const flex2 = layout.add3(.flex, .{}, &.{ btn, btn2 });
            layout.set_handler(btn, &handler);
            break :c flex2;
        };
        // const menu_bar = layout.add(.{ .type = .button });
        const font_view = layout.add2(.font_view, .{
            .font = app.font,
        });
        const font_map = layout.add2(.font_map, .{
            .columns = 32,
            .subscriber = font_view,
            .font = app.font,
        });
        layout.set(flex, .children, &.{ menu_bar, font_map, font_view });
        break :b flex;
    };

    const bar = try app.new_window(.xdg_toplevel, main_widget);

    const popup_flex = b: {
        const flex = layout.add2(.flex, .{ .orientation = .vertical });
        const btn = layout.add2(.button, .{});
        const btn2 = layout.add3(.button, .{}, &.{
            layout.add2(.label, .{}),
        });
        layout.set(flex, .children, &.{ btn, btn2 });
        break :b flex;
    };

    handler = .{
        .wl_surface = null,
        .parent = bar,
        .widget = popup_flex,
    };

    try app.client.recvEvents();
}

const std = @import("std");

const wlnd = @import("wayland");
const tk = @import("toolkit");
const PaintCtx = tk.PaintCtx;
const widget = tk.widget;
const Layout = widget.Layout;
const WidgetIdx = widget.WidgetIdx;

const App = tk.App;
const Font = tk.Font;
const Rect = tk.Rect;
const Size = tk.Size;
const Color = tk.Color;
