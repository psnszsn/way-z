const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub const Glyph = struct {
    rows: std.PackedIntArrayEndian(u1, .big, 8 * 13) = undefined,
    width: u8 = 5,
    height: u8 = 10,

    pub fn bitAt(self: *const Glyph, x: usize, y: usize) bool {
        const bits_per_row = (self.width / 9 + 1) * 8;
        return self.rows.get(bits_per_row * y + x) == 1;
    }

    pub fn format(self: Glyph, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll("\n");
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                if (self.bitAt(x, y)) {
                    try writer.writeAll("█");
                } else {
                    try writer.writeAll(" ");
                }
            }
            try writer.writeAll("|\n");
        }
    }
    pub fn init(data: []const u8, width: u8, height: u8) Glyph {
        var g = Glyph{
            .rows = undefined,
            .width = width,
            .height = height,
        };
        std.debug.print("w {} h {} \n", .{ width, height });
        std.debug.print("inner {} data {} \n", .{ g.rows.bytes.len, data.len });
        @memcpy(g.rows.bytes[0..data.len], data);
        return g;
    }
};

pub const Range = struct {
    // data: MultiArray(256, Glyph),
    data: [256]Glyph = undefined,
};

pub const Font = struct {
    // glyphs: std.AutoHashMap(u21, Glyph),
    range0: Range = .{},
    glyph_spacing: u8 = 2,
    glyph_height: u8 = 13,
    glyph_width: u8 = 8,

    pub fn glyphBitmap(self: *const Font, code_point: u21) Glyph {
        std.debug.assert(code_point / 256 == 0);
        return self.range0.data[code_point];
    }

    pub fn splitNth(buf: []const u8, split: []const u8, nth: usize) ![]const u8 {
        var it = mem.split(u8, buf, split);
        var i: usize = 0;
        while (it.next()) |line| : (i += 1) {
            if (i == nth) {
                return line;
            }
        }
        return error.NotFound;
    }

    pub fn parseBdfMeta(line: []const u8) struct { k: []const u8, v: []const u8 } {
        const bs_index = mem.indexOf(u8, line, " ").?;
        const k = line[0..bs_index];
        const v = line[bs_index..];
        return .{ .k = k, .v = std.mem.trim(u8, v, " ") };
    }

    pub fn parseBdfChar(it: *mem.TokenIterator(u8, .any)) !?struct { Glyph, u21 } {
        var current = Glyph{};
        var encoding: ?u21 = undefined;
        var offset_x: i8 = undefined;
        var offset_y: i8 = undefined;
        while (it.next()) |line_| {
            if (mem.startsWith(u8, line_, "BBX")) {
                const meta = parseBdfMeta(line_);
                var bbx_it = mem.tokenize(u8, meta.v, " ");
                current.width = try std.fmt.parseInt(u8, bbx_it.next().?, 0);
                current.height = try std.fmt.parseInt(u8, bbx_it.next().?, 0);
                offset_x = try std.fmt.parseInt(i8, bbx_it.next().?, 0);
                offset_y = try std.fmt.parseInt(i8, bbx_it.next().?, 0);
            } else if (mem.startsWith(u8, line_, "ENCODING")) {
                const meta = parseBdfMeta(line_);
                // const enc = try splitNth(meta.v, " ", 1);
                if (mem.eql(u8, meta.v, "-1")) {
                    encoding = null;
                } else {
                    encoding = try std.fmt.parseInt(u21, meta.v, 0);
                }
            } else if (mem.startsWith(u8, line_, "BITMAP")) {
                const top_offset: u8 = blk: {
                    const temp: i8 = @intCast(13 - current.height);
                    break :blk @intCast(temp - offset_y - 3);
                };

                for (top_offset..top_offset + current.height) |i| {
                    const s = it.next().?;

                    if (current.width / 9 + 1 > 1) {
                        // double width char
                        continue;
                    }
                    const h = try std.fmt.parseInt(u8, s[0..2], 16);
                    current.rows.bytes[i] = h;
                }

                if (mem.eql(u8, it.next().?, "ENDCHAR")) {
                    if (encoding == null) return null;
                    return .{ current, encoding.? };
                }
                unreachable;
            }
        }
        unreachable;
    }

    pub fn fromBdf(buf: []const u8) !Font {
        var f = Font{};
        var it = mem.tokenize(u8, buf, "\n");

        while (it.next()) |line| {
            if (mem.startsWith(u8, line, "STARTCHAR")) {
                // const meta = parseBdfMeta(line);
                // std.debug.print("startchar {s}\n", .{meta.v});

                const c = try parseBdfChar(&it) orelse continue;
                const r = c.@"1" / 256;
                if (r == 0) {
                    f.range0.data[c.@"1"] = c.@"0";
                }

                // @panic("nop");
            }
        }

        return f;
    }
};

pub fn cozette(alloc: std.mem.Allocator) !*Font {
    const font = try alloc.create(Font);
    font.* = try Font.fromBdf(@embedFile("cozette.bdf"));
    return font;
}

test cozette {
    const font = try cozette(std.testing.allocator);
    defer std.testing.allocator.destroy(font);
    const b = font.glyphBitmap('R');
    std.debug.print("B {}\n", .{b});
}
