const std = @import("std");
const mem = std.mem;

pub const Glyph = struct {
    rows: std.PackedIntSliceEndian(u1, .big),
    width: u8 = 5,
    height: u8 = 13,

    pub fn bitAt(self: *const Glyph, x: usize, y: usize) bool {
        // std.log.info("asd{}", .{y});
        const bits_per_row = (self.width / 9 + 1) * 8;
        return self.rows.get(bits_per_row * y + x) == 1;
    }

    pub fn format(self: Glyph, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
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
};

const RangeMask = struct {
    masks: []const usize,
    pub fn count(rm: RangeMask) usize {
        var total: usize = 0;
        for (rm.masks) |mask| {
            total += @popCount(mask);
        }
        return total;
    }
};

pub const Font = struct {
    glyph_data: []u8 = undefined,
    range_masks: []const usize = undefined,
    glyph_widths: []u8 = undefined,
    glyph_spacing: u8 = 2,
    glyph_height: u8 = 13,
    glyph_width: u8 = 5,

    pub fn deinit(f: *Font, alloc: std.mem.Allocator) void {
        alloc.free(f.range_masks);
        alloc.free(f.glyph_data);
        alloc.free(f.glyph_widths);
    }

    pub fn glyph_size(self: *const Font) u32 {
        const bits_per_row = (self.glyph_width / 9 + 1) * 8;
        return bits_per_row * self.glyph_height;
    }

    pub fn range_index(self: *const Font, range_num: u32) ?usize {
        const mask_i = range_num / 64;
        const m = self.range_masks[mask_i];
        const curr_mask = @as(usize, 1) << @as(u6, @intCast(range_num % 64));
        if (m & curr_mask == 0) return null;

        const next_mask = @as(usize, std.math.maxInt(usize)) << @as(u6, @intCast(range_num % 64));
        const index = @popCount(m & ~next_mask);

        const prev = (RangeMask{ .masks = self.range_masks[0..mask_i] }).count();

        return prev + index;
    }
    pub fn glyph_index(self: *const Font, code_point: u21) usize {
        const r_index = self.range_index(code_point / 256).?;
        return r_index * 256 + code_point % 256;
    }
    pub fn glyphBitmap(self: *const Font, code_point: u21) Glyph {
        // std.log.info("code_point={}", .{code_point});
        const _glyph_index = self.glyph_index(code_point);
        const _glyph_size = self.glyph_size();

        const glyph_data = self.glyph_data[_glyph_index * _glyph_size ..][0.._glyph_size];
        return Glyph{
            .rows = std.PackedIntSliceEndian(u1, .big).init(glyph_data, _glyph_size),
            .width = self.glyph_widths[_glyph_index],
            .height = self.glyph_height,
        };
    }
};

pub const BdfParser = struct {
    font: Font = .{},
    offset_x: i8 = 0,
    offset_y: i8 = 0,

    pub const CharIterator = struct {
        it: std.mem.TokenIterator(u8, .scalar),

        const Char = struct {
            name: []const u8,
            encoding: u21,
            bbx: BBX,
            bitmap: []const u8,
        };

        const State = union(enum) {
            char: Char,
            nochar: void,
        };
        pub fn next(ci: *CharIterator) ?Char {
            var state: State = .nochar;
            while (ci.it.next()) |line| {
                switch (state) {
                    .nochar => {
                        if (parse_prop(line, "STARTCHAR")) |value| {
                            state = .{ .char = undefined };
                            state.char.name = value;
                        }
                    },
                    .char => |*c| {
                        if (parse_prop(line, "BBX")) |value| {
                            c.bbx = parse_bdf_value(value, BBX) catch @panic("TODO");
                        } else if (parse_prop(line, "ENCODING")) |value| {
                            if (mem.eql(u8, value, "-1")) {
                                @panic("Asd");
                                // state = .nochar;
                                // continue;
                            } else {
                                std.log.info("value={s}", .{value});
                                c.encoding = std.fmt.parseInt(u21, value, 0) catch @panic("TODO");
                            }
                            std.log.info("encoding={any}", .{c.encoding});
                        } else if (parse_prop(line, "BITMAP")) |_| {
                            const start_i = ci.it.index + 1;
                            for (0..c.bbx.height) |_| {
                                _ = ci.it.next();
                            }
                            const end_i = ci.it.index;
                            c.bitmap = ci.it.buffer[start_i..end_i];
                        } else if (parse_prop(line, "ENDCHAR")) |_| {
                            return c.*;
                        }
                    },
                }
            }
            return null;
        }
    };
    pub fn parse(buf: []const u8, alloc: std.mem.Allocator) !Font {
        var p = BdfParser{};
        var it = mem.tokenize(u8, buf, "\n");

        while (it.next()) |line| {
            if (parse_prop(line, "FONTBOUNDINGBOX")) |val| {
                const bbx = try parse_bdf_value(val, BBX);
                p.font.glyph_width = bbx.width;
                p.font.glyph_height = bbx.height;
                p.offset_x = bbx.offset_x;
                p.offset_y = bbx.offset_y;
            } else if (parse_prop(line, "ENDPROPERTIES")) |_| {
                const rest = it.rest();
                {
                    const masks = range_mask_alloc(rest, alloc);

                    const glyph_size: u32 = p.font.glyph_size();
                    p.font.glyph_data = try alloc.alloc(u8, masks.count() * 256 * glyph_size);
                    p.font.glyph_widths = try alloc.alloc(u8, masks.count() * 256);
                    std.log.info("masks.count()={}", .{masks.count()});
                    @memset(p.font.glyph_data, 0);
                    @memset(p.font.glyph_widths, 0);
                    p.font.range_masks = masks.masks;
                }

                var char_it = CharIterator{
                    .it = std.mem.tokenizeScalar(u8, buf, '\n'),
                };
                while (char_it.next()) |char| {
                    var bitmap_it = std.mem.splitScalar(u8, char.bitmap, '\n');
                    const glyph = p.font.glyphBitmap(char.encoding);
                    var height = char.bbx.height;
                    const overflow: u8 = height -| p.font.glyph_height;
                    height -= overflow;
                    const top_offset: u8 = blk: {
                        const temp: i8 = @intCast(p.font.glyph_height - height);
                        break :blk @intCast(temp - char.bbx.offset_y + p.offset_y);
                    };
                    // std.log.info("top_offset={}", .{top_offset});

                    for (top_offset..top_offset + height) |i| {
                        const s = bitmap_it.next().?;
                        std.log.info("s={s}", .{s});

                        const bytes_per_line = char.bbx.width / 9 + 1;
                        for (0..bytes_per_line) |b| {
                            const h2 = try std.fmt.parseInt(u8, s[b * bytes_per_line ..][0..2], 16);
                            glyph.rows.bytes[bytes_per_line * i + b] = h2;
                        }
                    }
                    for (0..overflow) |_| {
                        _ = bitmap_it.next().?;
                    }
                    p.font.glyph_widths[p.font.glyph_index(char.encoding)] = char.bbx.width;
                }

                return p.font;
            }
        }
        return error.NoEndChars;
    }
    pub fn range_mask_alloc(buf: []const u8, alloc: std.mem.Allocator) RangeMask {
        var max_range_i: usize = 0;
        var range_mask = [_]usize{0} ** 70;
        var char_it = CharIterator{
            .it = std.mem.tokenizeScalar(u8, buf, '\n'),
        };
        while (char_it.next()) |char| {
            std.log.info("char={s}", .{char.bitmap});
            const range = char.encoding / 256;
            const i = range / 64;
            if (i > max_range_i) max_range_i = i;
            const mask = @as(usize, 1) << @as(u6, @intCast(range % 64));
            std.debug.print("char name {s}", .{char.name});
            range_mask[i] |= mask;
        }
        for (range_mask, 0..) |m, m_i| {
            for (0..64) |i| {
                if (m & (@as(usize, 1) << @intCast(i)) != 0) {
                    std.log.info("bit={}", .{m_i * 64 + i});
                }
            }
        }
        // std.posix.exit(66);
        // std.log.info("max_range_i={}", .{max_range_i});
        return .{ .masks = alloc.dupe(usize, range_mask[0 .. max_range_i + 1]) catch @panic("OOM") };
    }

    pub fn parse_prop(line: []const u8, prop: []const u8) ?[]const u8 {
        if (mem.startsWith(u8, line, prop)) {
            const bs_index = mem.indexOfScalar(u8, line, ' ') orelse {
                std.debug.assert(mem.eql(u8, line, prop));
                return "";
            };
            const k = line[0..bs_index];
            std.debug.assert(mem.eql(u8, k, prop));
            const v = line[bs_index..];
            return std.mem.trim(u8, v, " ");
        }
        return null;
    }

    pub fn parse_bdf_value(value: []const u8, comptime T: type) !T {
        var it = mem.tokenize(u8, value, " ");
        var result: T = undefined;
        switch (@typeInfo(T)) {
            .Struct => |s| {
                inline for (s.fields) |field| {
                    @field(result, field.name) = try std.fmt.parseInt(field.type, it.next().?, 0);
                }
            },
            .Int => {
                result = try std.fmt.parseInt(T, it.next().?, 0);
            },
            else => unreachable,
        }
        return result;
    }

    const BBX = struct {
        width: u8,
        height: u8,
        offset_x: i8,
        offset_y: i8,
    };
};

pub fn cozette(alloc: std.mem.Allocator) !*Font {
    const font = try alloc.create(Font);
    font.* = try BdfParser.parse(@embedFile("cozette.bdf"), alloc);
    return font;
}

// test cozette {
//     const font = try cozette(std.testing.allocator);
//     defer std.testing.allocator.destroy(font);
//     const b = font.glyphBitmap('R');
//     std.debug.print("B {}\n", .{b});
// }
//
test "range_index" {
    const f = try cozette(std.testing.allocator);
    defer std.testing.allocator.destroy(f);
    defer f.deinit(std.testing.allocator);
    // const f = Font{};
    // try std.testing.expectEqual(1, f.range_index(500));
    try std.testing.expectEqual(0, f.range_index('a' / 256));
    try std.testing.expectEqual(10, f.range_index('℅' / 256));
}
