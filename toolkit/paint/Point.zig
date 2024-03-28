const Self = @This();
const std = @import("std");

x: u32,
y: u32,

pub const ZERO = Self{
    .x = 0,
    .y = 0,
};
pub const INF = Self{
    .x = std.math.maxInt(u32),
    .y = std.math.maxInt(u32),
};

pub fn init(x: u32, y: u32) Self {
    return Self{ .x = x, .y = y };
}

pub fn translated(self: Self, point: Self) Self {
    return .{ .x = self.x + point.x, .y = self.y + point.y };
}

pub fn subtracted(self: Self, point: Self) Self {
    return .{ .x = self.x - point.x, .y = self.y - point.y };
}
