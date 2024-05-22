const std = @import("std");
const Rect = @import("./paint/Rect.zig");
const Point = @import("./paint/Point.zig");
const ColorU32 = @import("paint/color.zig").Color;
const Font = @import("./font/bdf.zig").Font;

pub const PaintCtxU32 = PaintCtx(ColorU32);

pub fn PaintCtx(comptime Color: type) type {
    return struct {
        const Self = @This();
        buffer: []Color,
        width: u32,
        height: u32,
        clip: Rect,

        pub inline fn rect(self: *const Self) Rect {
            return .{
                .x = 0,
                .y = 0,
                .width = self.width,
                .height = self.height,
            };
        }

        const DrawCharOpts = struct {
            rect: ?Rect = null,
            color: Color = Color.default,
            font: ?*Font = null,
            scale: u32 = 1,
        };

        pub inline fn pixel(self: *const Self, x: u32, y: u32, opts: DrawCharOpts) void {
            const actual_y = if (opts.rect) |r| r.y + y else y;
            const actual_x = if (opts.rect) |r| r.x + x else x;
            if (opts.scale == 1) {
                if (!self.clip.contains(actual_x, actual_y)) return;
                if (actual_x >= self.width or actual_y >= self.height) return;
                std.debug.assert(actual_x < self.width);
                std.debug.assert(actual_y < self.height);
                self.buffer[actual_y * self.width + actual_x] = opts.color;
            } else {
                self.fill(.{
                    .rect = .{
                        .x = actual_x,
                        .y = actual_y,
                        // .x = actual_x * opts.scale,
                        // .y = actual_y * opts.scale,
                        .width = opts.scale,
                        .height = opts.scale,
                    },
                    .color = opts.color,
                });
            }
        }

        pub fn fill(self: *const Self, opts: DrawCharOpts) void {
            var rct = opts.rect orelse self.rect();
            rct.intersect(self.clip);
            // rct.intersect(self.rect());
            // std.log.info("top {} bottom {}", .{top,bottom});
            for (rct.top()..rct.bottom()) |y| {
                // for (top..bottom + 1) |y| {
                @memset(self.buffer[y * self.width + rct.x ..][0..rct.width], opts.color);
            }
        }

        pub fn char(self: *const Self, code_point: u21, opts: DrawCharOpts) Rect {
            const font = opts.font.?;
            const bitmap = font.glyphBitmap(code_point);

            for (0..font.glyph_height) |_y| {
                const y: u8 = @intCast(_y);
                for (0..bitmap.width) |_x| {
                    const x: u8 = @intCast(_x);
                    if (bitmap.bitAt(x, y)) {
                        self.pixel(x, y, .{ .rect = opts.rect, .color = opts.color, .scale = opts.scale });
                    }
                }
            }
            return .{ .width = bitmap.width, .height = bitmap.height };
        }
        pub fn text(self: *const Self, _text: []const u8, opts: DrawCharOpts) void {
            const s = std.unicode.Utf8View.init(_text) catch unreachable;
            var it = s.iterator();
            var i: u32 = 0;
            var glyph_rect = opts.rect orelse self.rect();
            const font = opts.font.?;
            glyph_rect.width = font.glyph_width;
            glyph_rect.height = font.glyph_height;

            while (it.nextCodepoint()) |code_point| {
                // if (code_point == ' ') {
                //     continue;
                // }
                const drawn_size = self.char(code_point, .{ .rect = glyph_rect, .font = font, .color = opts.color, .scale = opts.scale });
                glyph_rect.translate_by(drawn_size.width + font.glyph_spacing, 0);
                i += 1;
            }
        }

        pub fn line(self: *const Self, pa1: *const Point, pa2: *const Point, color: Color, thickness: u32) void {
            var p1 = pa1.*;
            var p2 = pa2.*;

            if (p1.x == p2.x) {
                if (p1.y > p2.y)
                    std.mem.swap(Point, &p1, &p2);
                var y: u32 = p1.y;
                while (y < p2.y) : (y += thickness) {
                    self.pixel(p1.x, y, .{ .scale = thickness, .color = color });
                }
                self.pixel(p1.x, p2.y, .{ .scale = thickness, .color = color });
                return;
            }

            if (p1.y == p2.y) {
                if (p1.x > p2.x)
                    std.mem.swap(Point, &p1, &p2);
                var x: u32 = p1.x;
                while (x < p2.x) : (x += thickness) {
                    self.pixel(x, p1.y, .{ .scale = thickness, .color = color });
                }
                self.pixel(p2.x, p1.y, .{ .scale = thickness, .color = color });
                return;
            }

            const adx = if (p2.x > p1.x) p2.x - p1.x else p1.x - p2.x;
            const ady = if (p2.y > p1.y) p2.y - p1.y else p1.y - p2.y;

            if (adx > ady) {
                if (p1.x > p2.x) {
                    std.mem.swap(Point, &p1, &p2);
                }
            } else {
                if (p1.y > p2.y) {
                    std.mem.swap(Point, &p1, &p2);
                }
                // std.mem.swap(Point, &p1, &p2);
                // std.mem.swap(Point, p1, p2);
            }

            const dx = @as(i64, @intCast(p2.x)) - @as(i64, @intCast(p1.x));
            const dy = @as(i64, @intCast(p2.y)) - @as(i64, @intCast(p1.y));
            // const dy = p2.y - p1.y;
            var err: i64 = 0;

            if (dx > dy) {
                const y_step: i32 = if (dy == 0) 0 else blk: {
                    const a: i32 = if (dy > 0) 1 else -1;
                    break :blk a;
                };
                const delta_error: i64 = @intCast(2 * (@abs(dy))); //TODO: abs
                var y = p1.y;
                var x = p1.x;
                while (x <= p2.x) {
                    self.pixel(x, y, .{ .scale = thickness, .color = color });
                    err += delta_error;
                    if (err >= dx) {
                        if (y_step > 0) {
                            y += @as(u32, @intCast(@abs(y_step)));
                        } else {
                            const abs_y = @as(u32, @intCast(@abs(y_step)));
                            if (y > abs_y) {
                                y -= abs_y;
                            } else {
                                y = 0;
                            }
                        }
                        err -= 2 * dx;
                    }
                    x += 1;
                }
            } else {
                // const x_step: u32 = if (dx == 0) 0 else 1;
                const x_step: i32 = if (dx == 0) 0 else blk: {
                    const a: i32 = if (dx > 0) 1 else -1;
                    break :blk a;
                };
                const delta_error: i64 = @intCast(2 * (@abs(dx)));
                var x = p1.x;
                var y = p1.y;
                while (y <= p2.y) {
                    self.pixel(x, y, .{ .scale = thickness, .color = color });
                    err += delta_error;
                    if (err >= dy) {
                        if (x_step > 0) {
                            x += @as(u32, @intCast(@abs(x_step)));
                        } else {
                            // print("x value: {}\n", .{x_step});
                            const abs_x = @as(u32, @intCast(@abs(x_step)));
                            if (x > abs_x) {
                                x -= abs_x;
                            } else {
                                x = 0;
                            }
                        }
                        // x += x_step;
                        err -= 2 * dy;
                    }
                    y += 1;
                }
            }

            // var x: u32 = p1.x;
            // while (x < p2.x) {
            //     var y = p1.y + dy * (x - p1.x) / dx;
            //     self.drawPixel(x, y, thickness);
            //     x += 1;
            // }
        }

        const DrawPanelOpts = struct {
            depth: u8 = 1,
            hover: bool = false,
            press: bool = false,
            rect: Rect,
        };

        pub fn panel(self: *const Self, opts: DrawPanelOpts) void {
            var color_bg = Color.theme.background;
            var color_shadow = Color.theme.shadow;
            var color_light = Color.theme.light;

            if (opts.press) {
                color_bg = Color.ggray(204);
                color_shadow = Color.theme.background;
                color_light = Color.theme.shadow;
            } else if (opts.hover) {
                color_bg = Color.ggray(240);
                // color_bg = Color.NamedColor.teal;
            }

            // background
            self.fill(.{ .rect = opts.rect, .color = color_bg });
            const offset = opts.depth;

            //shadow
            self.line(
                &Point.init(opts.rect.right() - offset, opts.rect.top()),
                &Point.init(opts.rect.right() - offset, opts.rect.bottom() - offset),
                color_shadow,
                opts.depth,
            );

            self.line(
                &Point.init(opts.rect.left(), opts.rect.bottom() - offset),
                &Point.init(opts.rect.right() - offset, opts.rect.bottom() - offset),
                color_shadow,
                opts.depth,
            );

            // light
            self.line(
                &Point.init(opts.rect.left(), opts.rect.top()),
                &Point.init(opts.rect.left(), opts.rect.bottom() - 2 * offset),
                color_light,
                opts.depth,
            );

            self.line(
                &Point.init(opts.rect.left(), opts.rect.top()),
                &Point.init(opts.rect.right() - opts.depth, opts.rect.top()),
                color_light,
                opts.depth,
            );
        }

        pub fn border(self: *const Self) void {
            const thickness = 5;
            var i: u32 = 0;
            while (i < thickness) : (i += 1) {
                var it = self.rect.shrunkenUniform(i).borderIterator();
                while (it.next()) |p| {
                    self.putRaw(p.x, p.y, Color.NamedColor.red);
                }
            }
        }

        pub const ClippedPaintCtx = struct {
            ctx: *const Self,
            clip: Rect,
        };
        pub fn clipped_painter(self: *const Self, clip: Rect) ClippedPaintCtx {
            return .{
                .ctx = self,
                .clip = clip,
            };
        }
        pub fn with_clip(self: *const Self, clip: Rect) Self {
            var s = self.*;
            s.clip = clip;
            return s;
        }
    };
}
