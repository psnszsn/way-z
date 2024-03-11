const Size = @This();
const Rect = @import("Rect.zig");

width: usize,
height: usize,

pub const ZERO = Size{
    .width = 0,
    .height = 0,
};
pub fn init(width: usize, height: usize) Size {
    return .{
        .width = width,
        .height = height,
    };
}

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

pub fn toMinmaxTight(self: Size) Minmax {
    return Minmax{
        .min = self,
        .max = self,
    };
}

pub const Minmax = struct {
    min: Size,
    max: Size,

    pub fn init(min: Size, max: Size) Minmax {
        return .{
            .min = min,
            .max = max,
        };
    }

    pub fn loose(max: Size) Minmax {
        return Minmax{
            .min = ZERO,
            .max = max,
        };
    }
};
