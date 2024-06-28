const Self = @This();
const std = @import("std");

x: i32,
y: i32,

pub const ZERO = Self{
    .x = 0,
    .y = 0,
};
pub const INF = Self{
    .x = std.math.maxInt(i32),
    .y = std.math.maxInt(i32),
};

pub fn init(x: i32, y: i32) Self {
    return Self{ .x = x, .y = y };
}

pub fn translated(self: Self, point: Self) Self {
    return .{ .x = self.x + point.x, .y = self.y + point.y };
}

pub fn subtracted(self: Self, point: Self) Self {
    return .{ .x = self.x - point.x, .y = self.y - point.y };
}
