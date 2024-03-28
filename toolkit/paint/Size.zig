const Size = @This();
const Rect = @import("Rect.zig");

width: u32,
height: u32,

pub const ZERO = Size{
    .width = 0,
    .height = 0,
};

pub fn toRect(self: Size) Rect {
    return .{
        .x = 0,
        .y = 0,
        .width = self.width,
        .height = self.height,
    };
}

pub fn isZero(self: Size) bool {
    return (self.width == 0 or self.height == 0);
}

pub fn containsRect(self: Size, rect: Rect) bool {
    return self.width >= rect.right() and
        self.height >= rect.bottom();
}

pub const Minmax = struct {
    min: Size,
    max: Size,

    pub const ZERO = Minmax{
        .min = Size.ZERO,
        .max = Size.ZERO,
    };

    pub fn tight(size: Size) Minmax {
        return .{
            .min = size,
            .max = size,
        };
    }

    pub fn loose(max: Size) Minmax {
        return Minmax{
            .min = Size.ZERO,
            .max = max,
        };
    }
};
