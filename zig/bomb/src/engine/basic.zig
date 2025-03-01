pub const Vector = struct {
    x: usize = 0,
    y: usize = 0,

    pub fn isSame(self: Vector, other: Vector) bool {
        return self.x == other.x and self.y == other.y;
    }
};

pub const Rectangle = struct {
    x: usize = 0,
    y: usize = 0,
    width: usize = 0,
    height: usize = 0,

    pub fn init(x: usize, y: usize, width: usize, height: usize) Rectangle {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn center(self: Rectangle) Vector {
        return Vector{
            .x = (self.x + self.width) / 2,
            .y = (self.y + self.height) / 2,
        };
    }

    pub fn scale(self: Rectangle, factor: usize) Rectangle {
        return Rectangle{
            .x = self.x * factor,
            .y = self.y * factor,
            .width = self.width * factor,
            .height = self.height * factor,
        };
    }
};
