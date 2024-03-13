const Self = @This();
const std = @import("std");

x: usize,
y: usize,

pub const ZERO = Self{
    .x = 0,
    .y = 0,
};
pub const INF = Self{
    .x = std.math.maxInt(usize),
    .y = std.math.maxInt(usize),
};

pub fn init(x: usize, y: usize) Self {
    return Self{ .x = x, .y = y };
}

pub fn translated(self: Self, point: Self) Self {
    return .{ .x = self.x + point.x, .y = self.y + point.y };
}

pub fn subtracted(self: Self, point: Self) Self {
    return .{ .x = self.x - point.x, .y = self.y - point.y };
}
