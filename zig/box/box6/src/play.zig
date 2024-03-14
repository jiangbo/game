const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

const Allocator = std.mem.Allocator;
pub fn init(allocator: Allocator, level: usize, box: engine.Texture) ?Play {
    const m = map.Map.init(allocator, level) catch |err| {
        std.log.err("init stage error: {}", .{err});
        return null;
    } orelse return null;
    return .{ .map = m, .box = box };
}

pub const Play = struct {
    map: map.Map,
    box: engine.Texture,

    pub fn update(self: *Play) ?@import("popup.zig").PopupType {
        if (engine.isPressed(engine.Key.space)) return .menu;

        // 操作角色移动的距离
        const Key = engine.Key;
        const delta: isize = switch (engine.getPressed()) {
            Key.w, Key.up => -@as(isize, @intCast(self.map.width)),
            Key.s, Key.down => @as(isize, @intCast(self.map.width)),
            Key.d, Key.right => 1,
            Key.a, Key.left => -1,
            else => return null,
        };

        const currentIndex = self.map.playerIndex();
        const index = @as(isize, @intCast(currentIndex)) + delta;
        if (index < 0 or index > self.map.size()) return null;

        // 角色欲前往的目的地
        const destIndex = @as(usize, @intCast(index));
        self.updatePlayer(currentIndex, destIndex, delta);

        return if (self.map.hasCleared()) .clear else null;
    }

    fn updatePlayer(play: *Play, cur: usize, dest: usize, delta: isize) void {
        var state = play.map.data;
        if (state[dest] == .SPACE or state[dest] == .GOAL) {
            // 如果是空地或者目标地，则可以移动
            state[dest] = if (state[dest] == .GOAL) .MAN_GOAL else .MAN;
            state[cur] = if (state[cur] == .MAN_GOAL) .GOAL else .SPACE;
        } else if (state[dest] == .BLOCK or state[dest] == .BLOCK_GOAL) {
            //  如果是箱子或者目的地上的箱子，需要考虑该方向上的第二个位置
            const index = @as(isize, @intCast(dest)) + delta;
            if (index < 0 or index > play.map.size()) return;

            const next = @as(usize, @intCast(index));
            if (state[next] != .SPACE and state[next] != .GOAL) return;

            state[next] = if (state[next] == .GOAL) .BLOCK_GOAL else .BLOCK;
            state[dest] = if (state[dest] == .BLOCK_GOAL) .MAN_GOAL else .MAN;
            state[cur] = if (state[cur] == .MAN_GOAL) .GOAL else .SPACE;
        }
    }

    pub fn draw(self: Play) void {
        for (0..self.map.height) |y| {
            for (0..self.map.width) |x| {
                const item = self.map.data[y * self.map.width + x];
                if (item != map.MapItem.WALL) {
                    self.drawCell(x, y, if (item.hasGoal()) .GOAL else .SPACE);
                }
                if (item != .SPACE) self.drawCell(x, y, item);
            }
        }
    }

    fn drawCell(play: Play, x: usize, y: usize, item: map.MapItem) void {
        var source = engine.Rectangle{ .width = 32, .height = 32 };
        source.x = item.toImageIndex() * source.width;
        const position = .{ .x = x * source.width, .y = y * source.height };
        play.box.drawRectangle(source, position);
    }

    pub fn deinit(self: Play) void {
        self.map.deinit();
    }
};
