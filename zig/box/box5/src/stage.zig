const std = @import("std");
const map = @import("map.zig");
const file = @import("file.zig");
const ray = @import("raylib.zig");

pub const SequenceType = enum { title, stage };
const Allocator = std.mem.Allocator;

pub fn init(allocator: Allocator, level: usize, box: ray.Texture2D) ?Stage {
    return doInit(allocator, level, box) catch |e| {
        std.log.err("init stage error: {}", .{e});
        return null;
    };
}

fn doInit(allocator: Allocator, level: usize, box: ray.Texture2D) !?Stage {
    var buf: [30]u8 = undefined;
    const path = try std.fmt.bufPrint(&buf, "data/stage/{}.txt", .{level});

    std.log.info("load stage: {s}", .{path});
    const text = try file.readAll(allocator, path);
    defer allocator.free(text);
    std.log.info("{s} text: \n{s}", .{ path, text });
    return parse(allocator, text, box);
}

fn parse(allocator: Allocator, text: []const u8, box: ray.Texture2D) !?Stage {
    var stage = parseText(text) orelse return null;

    var index: usize = 0;
    stage.data = try allocator.alloc(map.MapItem, stage.width * stage.height);
    for (text) |char| {
        if (char == '\r' or char == '\n') continue;
        stage.data[index] = map.MapItem.fromU8(char);
        index += 1;
    }
    stage.allocator = allocator;
    stage.box = box;
    return stage;
}

fn parseText(text: []const u8) ?Stage {
    var stage = Stage{};

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

pub const Stage = struct {
    width: usize = 0,
    height: usize = 0,
    data: []map.MapItem = undefined,
    allocator: std.mem.Allocator = undefined,
    box: ray.Texture2D = undefined,

    pub fn hasCleared(self: Stage) bool {
        for (self.data) |value| {
            if (value == map.MapItem.BLOCK) {
                return false;
            }
        } else return true;
    }

    pub fn playerIndex(self: Stage) usize {
        // 角色当前位置
        return for (self.data, 0..) |value, index| {
            if (value == .MAN or value == .MAN_ON_GOAL) break index;
        } else 0;
    }

    pub fn update(self: *Stage) ?SequenceType {
        // 操作角色移动的距离
        const delta: isize = switch (ray.GetKeyPressed()) {
            ray.KEY_W, ray.KEY_UP => -@as(isize, @intCast(self.width)),
            ray.KEY_S, ray.KEY_DOWN => @as(isize, @intCast(self.width)),
            ray.KEY_D, ray.KEY_RIGHT => 1,
            ray.KEY_A, ray.KEY_LEFT => -1,
            else => return null,
        };

        const currentIndex = self.playerIndex();
        const index = @as(isize, @intCast(currentIndex)) + delta;
        if (index < 0 or index > self.width * self.height) return null;

        // 角色欲前往的目的地
        const destIndex = @as(usize, @intCast(index));
        self.updatePlayer(currentIndex, destIndex, delta);

        return if (self.hasCleared()) .title else null;
    }

    fn updatePlayer(stage: *Stage, current: usize, dest: usize, delta: isize) void {
        var state = stage.data;
        if (state[dest] == .SPACE or state[dest] == .GOAL) {
            // 如果是空地或者目标地，则可以移动
            state[dest] = if (state[dest] == .GOAL) .MAN_ON_GOAL else .MAN;
            state[current] = if (state[current] == .MAN_ON_GOAL) .GOAL else .SPACE;
        } else if (state[dest] == .BLOCK or state[dest] == .BLOCK_ON_GOAL) {
            //  如果是箱子或者目的地上的箱子，需要考虑该方向上的第二个位置
            const index = @as(isize, @intCast(dest)) + delta;
            if (index < 0 or index > stage.width * stage.height) return;

            const next = @as(usize, @intCast(index));
            if (state[next] == .SPACE or state[next] == .GOAL) {
                state[next] = if (state[next] == .GOAL) .BLOCK_ON_GOAL else .BLOCK;
                state[dest] = if (state[dest] == .BLOCK_ON_GOAL) .MAN_ON_GOAL else .MAN;
                state[current] = if (state[current] == .MAN_ON_GOAL) .GOAL else .SPACE;
            }
        }
    }

    pub fn draw(self: Stage) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const item = self.data[y * self.width + x];
                if (item != map.MapItem.WALL) {
                    self.drawCell(x, y, if (item.hasGoal()) .GOAL else .SPACE);
                }
                if (item != .SPACE) self.drawCell(x, y, item);
            }
        }
    }

    fn drawCell(stage: Stage, x: usize, y: usize, item: map.MapItem) void {
        var source = ray.Rectangle{ .width = 32, .height = 32 };
        source.x = item.toImageIndex() * source.width;
        const dest = ray.Rectangle{
            .x = @as(f32, @floatFromInt(x)) * source.width,
            .y = @as(f32, @floatFromInt(y)) * source.height,
            .width = source.width,
            .height = source.height,
        };

        ray.DrawTexturePro(stage.box, source, dest, .{}, 0, ray.WHITE);
    }

    pub fn deinit(self: Stage) void {
        self.allocator.free(self.data);
    }
};
