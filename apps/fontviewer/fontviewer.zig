pub const widget_types = .{
    .font_view = GlyphView,
    .font_map = FontMap,
};

pub const std_options = std.Options{
    .log_level = .info,
};

const PopupHandler = struct {
    parent: *App.Surface,
    widget: WidgetIdx,
    wl_surface: ?wlnd.wl.Surface,
    layout: *Layout,
    pub fn handle_event(data: *PopupHandler, idx: WidgetIdx, ev: *const anyopaque) void {
        _ = ev; // autofix
        switch (data.layout.get(idx, .type)) {
            .button => {
                // const event = widget.WidgetEvent(.button);
                // _ = event; // autofix
                const app = data.layout.get_app();
                if (data.wl_surface) |s| {
                    const surface = app.find_wl_surface(s);
                    if (surface) |sf| {
                        sf.destroy();
                        return;
                    }
                }
                const rect = data.layout.get(idx, .rect);
                const popup = app.new_surface(.{ .xdg_popup = .{
                    .anchor = rect,
                    .parent = data.parent.role.xdg_toplevel.xdg_surface,
                } }, data.widget) catch unreachable;
                data.wl_surface = popup.wl_surface;
            },
            else => unreachable,
        }

        // std.log.info("data {?}", .{surface});
    }
};

const MenuHandler = struct {
    parent: *App.Surface,
    widget: WidgetIdx,
    wl_surface: ?wlnd.wl.Surface,
    pub fn handle_event(layout: *Layout, idx: WidgetIdx, ev: *const anyopaque, data: *MenuHandler) void {
        _ = layout; // autofix
        _ = ev; // autofix
        _ = data; // autofix
        std.log.info("idx={}", .{idx});
    }
};

pub fn find_next_range(font: *const Font, current: u32, reverse: bool) ?u32 {
    const max = 64 * font.range_masks.len - 1;
    var range: u32 = current + 1;
    while (true) {
        // std.log.info("range={}/{}", .{ range, max });
        if (range > max) return null;
        if (font.range_index(range)) |_| {
            // std.log.info("selected range: {}", .{range});
            return range;
        } else {
            if (reverse) {
                range -|= 1;
            } else {
                range +|= 1;
            }
        }
    }
}

pub fn handle_next_range(state: *State, idx: WidgetIdx, ev: *const anyopaque) void {
    _ = idx; // autofix
    _ = ev; // autofix
    const next = find_next_range(state.inner.font, state.inner.selected_range, false) orelse 0;
    state.set_value(.selected_range, next);
}

pub fn font_map_handler(state: *State, idx: WidgetIdx, ev: *const anyopaque) void {
    _ = idx; // autofix
    const event: *const FontMap.Event = @ptrCast(@alignCast(ev));
    state.set_value(.selected_glyph, event.code_point_clicked);
}

const State = Signal(struct {
    selected_range: u32,
    selected_glyph: u21,
    font: *const Font,
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try App.new(allocator);
    defer app.deinit();

    const layout = &app.layout;
    try layout.init(app.client.allocator);

    var popup_handler: PopupHandler = undefined;
    var menu_handler: MenuHandler = undefined;

    var s = State.init(layout, allocator);
    defer s.deinit(allocator);
    s.inner = .{
        .selected_range = 1,
        .selected_glyph = 'a',
        .font = app.font,
    };

    const main_widget = b: {
        const flex = layout.add2(.flex, .{ .orientation = .vertical });
        const menu_bar = c: {
            const btn = layout.add2(.button, .{});
            const btn2 = layout.add2(.button, .{});

            const flex2 = layout.add3(.flex, .{}, &.{ btn, btn2 });
            layout.set_handler(btn, &popup_handler);
            layout.set_handler2(btn2, &handle_next_range, &s);
            break :c flex2;
        };
        // const menu_bar = layout.add(.{ .type = .button });
        const font_view = layout.add2(.font_view, .{
            .font = app.font,
        });
        const font_map = layout.add2(.font_map, .{
            .columns = 32,
            .font = app.font,
        });

        const scrollable = s: {
            var btns: [290]WidgetIdx = undefined;
            var current_range: u32 = 0;
            var i: u32 = 0;
            while (find_next_range(app.font, current_range, false)) |range| {
                current_range = range;
                btns[i] = layout.add2(.font_map, .{
                    .columns = 32,
                    .font = app.font,
                    .selected_range = range,
                });
                i += 1;
            }
            const subflex = layout.add2(.flex, .{ .orientation = .vertical });

            const scrollable = layout.add4(.scrollable, .{ .content = subflex });
            layout.set(subflex, .children, btns[0..i]);
            layout.set(scrollable, .flex, 1);
            break :s scrollable;
        };

        layout.set_handler2(font_map, &font_map_handler, &s);
        layout.set(flex, .children, &.{
            menu_bar,
            font_map,
            font_view,
            scrollable,
        });

        // s.connect(.selected_range, font_map, FontMap, .selected_range);
        // s.connect(.selected_glyph, font_map, FontMap, .selected_code_point);
        s.connect(.selected_glyph, font_view, GlyphView, .code_point);

        break :b flex;
    };

    const popup_flex = b: {
        const flex = layout.add2(.flex, .{ .orientation = .vertical });
        const btn = layout.add2(.button, .{});
        const btn2 = layout.add3(.button, .{}, &.{
            layout.add2(.label, .{}),
        });
        layout.set_handler(btn2, &menu_handler);
        layout.set(flex, .children, &.{ btn, btn2 });
        break :b flex;
    };

    // const sub_w = try app.new_surface(.{ .wl_subsurface = .{ .parent = bar.wl_surface } }, flex);
    // _ = sub_w; // autofix

    const bar = try app.new_surface(.xdg_toplevel, main_widget);
    defer bar.destroy();
    popup_handler = .{
        .wl_surface = null,
        .parent = bar,
        .widget = popup_flex,
        .layout = layout,
    };

    try app.client.recvEvents();
}

const std = @import("std");
const FontMap = @import("FontMap.zig");
const GlyphView = @import("GlyphView.zig");
const Signal = @import("signals.zig").Signal;

const wlnd = @import("wayland");
const tk = @import("toolkit");
const widget = tk.widget;
const Layout = widget.Layout;
const WidgetIdx = widget.WidgetIdx;

const App = tk.App;
const Font = tk.Font;
