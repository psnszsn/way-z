const Self = @This();

x: usize,
y: usize,

pub const ZERO = Self{
    .x = 0,
    .y = 0,
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
