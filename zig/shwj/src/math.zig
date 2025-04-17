const std = @import("std");

pub const FourDirection = enum { up, down, left, right };
pub const EightDirection = enum { up, down, left, right, leftUp, leftDown, rightUp, rightDown };
pub const epsilon = 1e-4;

pub const Vector2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub const zero = Vector2{ .x = 0, .y = 0 };

    pub fn init(x: f32, y: f32) Vector2 {
        return .{ .x = x, .y = y };
    }

    pub fn toVector3(self: Vector2, z: f32) Vector3 {
        return .{ .x = self.x, .y = self.y, .z = z };
    }

    pub fn add(self: Vector2, other: Vector2) Vector2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Vector2, other: Vector2) Vector2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x * scalar, .y = self.y * scalar };
    }

    pub fn length(self: Vector2) f32 {
        return std.math.sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn normalize(self: Vector2) Vector2 {
        return .{ .x = self.x / self.length(), .y = self.y / self.length() };
    }

    pub fn approx(self: Vector2, other: Vector2) bool {
        return std.math.approxEqAbs(f32, self.x, other.x, epsilon) and
            std.math.approxEqAbs(f32, self.y, other.y, epsilon);
    }
};

pub const Vector = Vector3;
pub const Vector3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub const zero = Vector3{ .x = 0, .y = 0, .z = 0 };

    pub fn init(x: f32, y: f32) Vector3 {
        return .{ .x = x, .y = y, .z = 0 };
    }

    pub fn toVector2(self: Vector3) Vector2 {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn add(self: Vector3, other: Vector3) Vector3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vector3, other: Vector3) Vector3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn scale(self: Vector3, scalar: f32) Vector3 {
        return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn dot(self: Vector3, other: Vector3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn mul(self: Vector3, other: Vector3) Vector3 {
        return .{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
    }

    pub fn div(self: Vector3, other: Vector3) Vector3 {
        return .{ .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z };
    }

    pub fn length(self: Vector3) f32 {
        return std.math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn normalize(self: Vector3) Vector3 {
        const len = self.length();
        return .{ .x = self.x / len, .y = self.y / len, .z = self.z / len };
    }

    pub fn rotate(self: Vector3, angle: f32) Vector3 {
        const cos = @cos(angle);
        const sin = @sin(angle);
        return .{
            .x = self.x * cos - self.y * sin,
            .y = self.x * sin + self.y * cos,
            .z = self.z,
        };
    }

    pub fn radians(self: Vector3) f32 {
        return std.math.atan2(self.y, self.x);
    }

    pub fn approx(self: Vector3, other: Vector3) bool {
        return std.math.approxEqAbs(f32, self.x, other.x, epsilon) and
            std.math.approxEqAbs(f32, self.y, other.y, epsilon) and
            std.math.approxEqAbs(f32, self.z, other.z, epsilon);
    }
};

pub const Rectangle = struct {
    position: Vector = .zero,
    size: Vector = .zero,

    pub fn left(self: Rectangle) f32 {
        return self.position.x;
    }

    pub fn top(self: Rectangle) f32 {
        return self.position.y;
    }

    pub fn right(self: Rectangle) f32 {
        return self.position.x + self.size.x;
    }

    pub fn bottom(self: Rectangle) f32 {
        return self.position.y + self.size.y;
    }

    pub fn intersect(self: Rectangle, other: Rectangle) bool {
        return self.left() < other.right() and self.right() > other.left() and
            self.top() < other.bottom() and self.bottom() > other.top();
    }

    pub fn contains(self: Rectangle, point: Vector) bool {
        return point.x >= self.left() and point.x < self.right() and
            point.y >= self.top() and point.y < self.bottom();
    }
};

pub var rand: std.Random = undefined;

pub fn randomF32(min: f32, max: f32) f32 {
    return rand.float(f32) * (max - min) + min;
}

pub fn randomU8(min: u8, max: u8) u8 {
    return rand.intRangeLessThanBiased(u8, min, max);
}
