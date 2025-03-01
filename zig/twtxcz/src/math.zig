const std = @import("std");

pub const Vector2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn add(self: Vector2, other: Vector2) Vector2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Vector2, other: Vector2) Vector2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn normalize(self: Vector2) Vector2 {
        if (self.x == 0 and self.y == 0) return .{};
        const length = std.math.sqrt(self.x * self.x + self.y * self.y);
        return .{ .x = self.x / length, .y = self.y / length };
    }
};

pub const Rectangle = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,

    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }

    pub fn contains(self: Rectangle, x: f32, y: f32) bool {
        return x >= self.x and x < self.x + self.width and
            y >= self.y and y < self.y + self.height;
    }
};
