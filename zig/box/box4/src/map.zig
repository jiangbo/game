const std = @import("std");
const ray = @import("raylib.zig");
const file = @import("file.zig");

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
};

var texture: ray.Texture2D = undefined;

pub fn draw(stage: Stage) void {
    for (0..stage.height) |y| {
        for (0..stage.width) |x| {
            const item = stage.data[y * stage.width + x];
            drawCell(x, y, item);
        }
    }
}

fn drawCell(x: usize, y: usize, item: MapItem) void {
    var source = ray.Rectangle{ .width = 32, .height = 32 };
    source.x = mapItemToIndex(item) * source.width;
    const dest = ray.Rectangle{
        .x = @as(f32, @floatFromInt(x)) * source.width,
        .y = @as(f32, @floatFromInt(y)) * source.height,
        .width = source.width,
        .height = source.height,
    };

    ray.DrawTexturePro(texture, source, dest, .{}, 0, ray.WHITE);
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

pub const Stage = struct {
    width: usize = 0,
    height: usize = 0,
    data: []MapItem = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator, level: usize) ?Stage {
        texture = ray.LoadTexture("images/box.png");
        return doInit(allocator, level) catch |e| {
            std.log.err("init stage error: {}", .{e});
            return null;
        };
    }

    fn doInit(allocator: std.mem.Allocator, level: usize) !?Stage {
        var buf: [30]u8 = undefined;
        const path = try std.fmt.bufPrint(&buf, "data/stage/{}.txt", .{level});

        std.log.info("load stage: {s}", .{path});
        const text = try file.readAll(allocator, path);
        defer allocator.free(text);
        std.log.info("{s} text: \n{s}", .{ path, text });
        return parse(allocator, text);
    }

    fn parse(allocator: std.mem.Allocator, text: []const u8) !?Stage {
        var stage = parseText(allocator, text) orelse return null;

        var index: usize = 0;
        stage.data = try allocator.alloc(MapItem, stage.width * stage.height);
        for (text) |char| {
            if (char == '\r' or char == '\n') continue;
            stage.data[index] = MapItem.fromU8(char);
            index += 1;
        }
        return stage;
    }

    fn parseText(allocator: std.mem.Allocator, text: []const u8) ?Stage {
        var stage = Stage{ .allocator = allocator };

        var width: usize = 0;
        for (text) |char| {
            if (char == '\r') continue;
            if (char != '\n') {
                width += 1;
                continue;
            }

            if (stage.height != 0 and stage.width != width) {
                std.log.err("stage width error, {} vs {}", .{ stage.width, width });
                return null;
            }
            stage.width = width;
            width = 0;
            stage.height += 1;
        }
        return stage;
    }

    pub fn hasBlock(self: Stage) bool {
        for (self.data) |value| {
            if (value == MapItem.BLOCK) {
                return true;
            }
        } else return false;
    }

    pub fn playerIndex(self: Stage) usize {
        // 角色当前位置
        return for (self.data, 0..) |value, index| {
            if (value == .MAN or value == .MAN_ON_GOAL) break index;
        } else 0;
    }

    pub fn deinit(self: Stage) void {
        ray.UnloadTexture(texture);
        self.allocator.free(self.data);
    }
};
