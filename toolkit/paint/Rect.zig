const Rect = @This();
const std = @import("std");
// const Point = @import("Point.zig");
// const Size = @import("Size.zig");

x: usize = 0,
y: usize = 0,
width: usize,
height: usize,

pub const ZERO = Rect{
    .width = 0,
    .height = 0,
};

pub const MAX = Rect{
    .width = std.math.maxInt(usize),
    .height = std.math.maxInt(usize),
};

pub inline fn left(self: *const Rect) usize {
    return self.x;
}
pub inline fn right(self: *const Rect) usize {
    return self.x + self.width - 1;
}
pub inline fn top(self: *const Rect) usize {
    return self.y;
}
pub inline fn bottom(self: *const Rect) usize {
    return self.y + self.height - 1;
}

pub fn contains_rect(self: Rect, other: Rect) bool {
    return self.left() <= other.left() and
        self.right() >= other.right() and
        self.top() <= other.top() and
        self.bottom() >= other.bottom();
}

pub fn intersect(self: *Rect, other: Rect) void {
    const l = @max(self.left(), other.left());
    const r = @min(self.right(), other.right());
    const t = @max(self.top(), other.top());
    const b = @min(self.bottom(), other.bottom());

    if (l > r or t > b) {
        self.* = ZERO;
        return;
    }

    self.x = l;
    self.y = t;
    self.width = (r - l) + 1;
    self.height = (b - t) + 1;
}

pub fn contains(self: Rect, x: usize, y: usize) bool {
    return x >= self.x and
        x < self.x + self.width and
        y >= self.y and
        y < self.y + self.height;
}

pub fn contains_point(self: Rect, point: Point) bool {
    return point.x >= self.x and
        point.x < self.x + self.width and
        point.y >= self.y and
        point.y < self.y + self.height;
}

pub fn shrink(self: *Rect, top_: usize, right_: usize, bottom_: usize, left_: usize) void {
    // std.debug.print("self: {} \n", .{self});
    self.x += left_;
    self.y += top_;
    // std.debug.print("tb: {} {} \n", .{ top_, bottom_ });
    // std.debug.print("lr: {} {} \n", .{ left_, right_ });
    self.width -= left_ + right_;
    self.height -= top_ + bottom_;
}

pub fn shrinkUniform(self: *Rect, s: usize) void {
    self.shrink(s, s, s, s);
}

pub fn shrunken(self: Rect, t: usize, r: usize, b: usize, l: usize) Rect {
    var rect = self;
    rect.shrink(t, r, b, l);
    return rect;
}

pub fn shrunken_uniform(self: Rect, s: usize) Rect {
    return self.shrunken(s, s, s, s);
}

pub fn translate_by(self: *Rect, x: usize, y: usize) void {
    self.x += x;
    self.y += y;
    // _ = y;
    // _ = x;
    // std.debug.print("x:{}, y: {}, self: {}\n", .{ x, y, self });

    // std.debug.assert(self.x <= self.width);
    // std.debug.assert(self.y <= self.height);
}

pub fn translated(self: Rect, x: usize, y: usize) Rect {
    return .{
        .x = self.x + x,
        .y = self.y + y,
        .width = self.width,
        .height = self.height,
    };
}

pub fn relative_to(self: Rect, parent: Rect) Rect {
    const t = self.translated(parent.x, parent.y);
    std.debug.assert(parent.contains_rect(t));
    return t;
}

// pub fn setSize(self: *Self, size: Size) void {
//     self.width = size.width;
//     self.height = size.height;
// }
pub fn setOrigin(self: *Rect, point: Point) void {
    self.x = point.x;
    self.y = point.y;
}
pub fn getSize(self: *const Rect) Size {
    return .{ .width = self.width, .height = self.height };
}

pub fn getPosition(self: Rect) Point {
    return .{ .x = self.x, .y = self.y };
}

pub fn getCenter(self: Rect) Point {
    return .{ .x = self.x + self.width / 2, .y = self.y + self.height / 2 };
}

const Point = @import("Point.zig");
const Size = @import("Size.zig");

pub fn borderIterator(self: *const Rect) BorderIterator {
    return .{
        .rect = self,
        .current = Point.init(self.x, self.y),
    };
}

pub const BorderIterator = struct {
    rect: *const Rect,
    current: Point,
    done: bool = false,

    pub fn next(self: *BorderIterator) ?Point {
        const rect = self.rect;
        if (self.done) return null;

        if (self.current.y == rect.top() and rect.left() <= self.current.x and self.current.x <= rect.right() - 1) {
            const result = self.current;
            self.current.x += 1;
            std.debug.assert(self.rect.contains(result));
            return result;
        }

        std.debug.print("right: {}\n", .{rect.right()});
        if (self.current.x == rect.right() and rect.top() <= self.current.y and self.current.y <= rect.bottom() - 1) {
            const result = self.current;
            self.current.y += 1;
            std.debug.assert(self.rect.contains(result));
            return result;
        }
        if (self.current.y == rect.bottom() and rect.left() + 1 <= self.current.x and self.current.x <= rect.right()) {
            const result = self.current;
            self.current.x -= 1;
            std.debug.assert(self.rect.contains(result));
            return result;
        }
        if (self.current.x == rect.left() and rect.top() + 2 <= self.current.y and self.current.y <= rect.bottom()) {
            const result = self.current;
            self.current.y -= 1;
            std.debug.assert(self.rect.contains(result));
            return result;
        }
        if (self.current.x == rect.left() and self.current.y == rect.top() + 1) {
            self.done = true;
            return self.current;
        }

        return null;
    }
};
