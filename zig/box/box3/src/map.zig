const std = @import("std");
const ray = @import("raylib.zig");

pub const stageWidth = 8;
pub const stageHeight = 5;
pub const stageLength = stageHeight * stageWidth;
const SCALE = 32; // 放大倍数

// 定义地图的类型
pub const MapItem = enum(u8) {
    SPACE = ' ',
    WALL = '#',
    GOAL = '.',
    BLOCK = 'o',
    BLOCK_ON_GOAL = 'O',
    MAN = 'p',
    MAN_ON_GOAL = 'P',

    fn fromInt(value: u8) MapItem {
        return @enumFromInt(value);
    }

    fn toInt(self: MapItem) u8 {
        return @intFromEnum(self);
    }
};

// 定义地图
const stageMap =
    \\########
    \\# .. p #
    \\# oo   #
    \\#      #
    \\########
;

var texture: ray.Texture2D = undefined;
var source: ray.Rectangle = undefined;

pub fn init(stage: []MapItem) void {
    var index: usize = 0;
    for (stageMap) |value| {
        if (value == '\n') continue;

        stage[index] = MapItem.fromInt(value);
        index += 1;
    }

    texture = ray.LoadTexture("images/box.png");
    source = ray.Rectangle{ .x = 0, .y = 0, .width = SCALE, .height = SCALE };
}

pub fn deinit() void {
    ray.UnloadTexture(texture);
}

pub fn draw(stage: []MapItem) void {
    for (0..stageHeight) |y| {
        for (0..stageWidth) |x| {
            const item = stage[y * stageWidth + x];
            std.debug.print("{c}", .{item.toInt()});
            drawCell(x, y, item);
        }
        std.debug.print("\n", .{});
    }
}

fn drawCell(x: usize, y: usize, item: MapItem) void {
    const posX = @as(f32, @floatFromInt(x)) * SCALE;
    const posY = @as(f32, @floatFromInt(y)) * SCALE;
    const position = ray.Vector2{ .x = posX, .y = posY };
    source.x = SCALE * mapItemToIndex(item);
    ray.DrawTextureRec(texture, source, position, ray.WHITE);
}

fn mapItemToIndex(item: MapItem) f32 {
    return switch (item) {
        .SPACE => 4,
        .WALL => 1,
        .BLOCK => 2,
        .GOAL => 3,
        .BLOCK_ON_GOAL => 2,
        .MAN => 0,
        .MAN_ON_GOAL => 0,
    };
}
