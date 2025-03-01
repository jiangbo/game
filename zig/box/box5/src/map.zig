const std = @import("std");

// 定义地图的类型
pub const MapItem = enum(u8) {
    SPACE = ' ',
    WALL = '#',
    GOAL = '.',
    BLOCK = 'o',
    BLOCK_ON_GOAL = 'O',
    MAN = 'p',
    MAN_ON_GOAL = 'P',

    pub fn fromU8(value: u8) MapItem {
        return @enumFromInt(value);
    }

    pub fn toU8(self: MapItem) u8 {
        return @intFromEnum(self);
    }

    pub fn hasGoal(self: MapItem) bool {
        return self == .BLOCK_ON_GOAL or self == .MAN_ON_GOAL;
    }

    pub fn toImageIndex(self: MapItem) f32 {
        return switch (self) {
            .SPACE => 4,
            .WALL => 1,
            .BLOCK => 2,
            .GOAL => 3,
            .BLOCK_ON_GOAL => 2,
            .MAN => 0,
            .MAN_ON_GOAL => 0,
        };
    }
};
