const Size = @This();
const Rect = @import("Rect.zig");

width: u32,
height: u32,

pub const ZERO = Size{
    .width = 0,
    .height = 0,
};

pub fn to_rect(self: Size) Rect {
    return .{
        .x = 0,
        .y = 0,
        .width = self.width,
        .height = self.height,
    };
}

pub fn is_zero(self: Size) bool {
    return (self.width == 0 or self.height == 0);
}

pub fn is_eql(self: Size, other: Size) bool {
    return self.width == other.width and
        self.height == other.height;
}

pub fn contains(self: Size, size: Size) bool {
    return self.width >= size.width and
        self.height >= size.height;
}

pub fn unite(self: Size, other: Size) Size {
    return .{
        .width = @max(self.width, other.width),
        .height = @max(self.height, other.height),
    };
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
