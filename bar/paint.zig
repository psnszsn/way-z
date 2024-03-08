const std = @import("std");
const Rect = @import("./paint/Rect.zig");
const ColorU32 = @import("./paint/Color.zig");
const Font = @import("./font/bdf.zig").Font;

pub const PaintCtxU32 = PaintCtx(ColorU32);

pub fn PaintCtx(comptime Color: type) type {
    return struct {
        const Self = @This();
        buffer: []Color,
        width: usize,
        height: usize,

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

        pub inline fn put(self: *const Self, x: usize, y: usize, opts: DrawCharOpts) void {
            const actual_y = if (opts.rect) |r| r.y + y else y;
            const actual_x = if (opts.rect) |r| r.x + x else x;
            if (opts.scale == 1) {
                std.debug.assert(actual_x < self.width);
                std.debug.assert(actual_y < self.height);
                self.buffer[actual_y * self.width + actual_x] = opts.color;
            } else {
                self.fill(.{
                    .rect = .{
                        .x = actual_x * opts.scale,
                        .y = actual_y * opts.scale,
                        .width = opts.scale,
                        .height = opts.scale,
                    },
                    .color = opts.color,
                });
            }
        }

        pub fn fill(self: *const Self, opts: DrawCharOpts) void {
            const rct = opts.rect orelse self.rect();
            for (rct.top()..rct.bottom() + 1) |y| {
                @memset(self.buffer[y * self.width + rct.x ..][0..rct.width], opts.color);
            }
        }

        pub fn draw_char(self: *const Self, code_point: u21, opts: DrawCharOpts) struct { width: usize, height: usize } {
            const font = opts.font.?;
            const bitmap = font.glyphBitmap(code_point);

            const offset = font.glyph_height - bitmap.height;
            for (0..bitmap.height) |y| {
                for (0..bitmap.width) |x| {
                    if (bitmap.bitAt(x, y)) {
                        self.put(x, y + offset, .{ .rect = opts.rect, .color = opts.color, .scale = opts.scale });
                    }
                }
            }
            return .{ .width = bitmap.width, .height = bitmap.height };
        }
        pub fn draw_text(self: *const Self, text: []const u8, opts: DrawCharOpts) void {
            const s = std.unicode.Utf8View.init(text) catch unreachable;
            var it = s.iterator();
            var i: usize = 0;
            var glyph_rect = opts.rect orelse self.rect();
            const font = opts.font.?;
            glyph_rect.width = font.glyph_width;
            glyph_rect.height = font.glyph_height;

            while (it.nextCodepoint()) |code_point| {
                // if (code_point == ' ') {
                //     continue;
                // }
                const drawn_size = self.draw_char(code_point, .{ .rect = glyph_rect, .font = font, .color = opts.color, .scale = opts.scale });
                glyph_rect.translate_by(drawn_size.width + font.glyph_spacing, 0);
                i += 1;
            }
        }
    };
}
