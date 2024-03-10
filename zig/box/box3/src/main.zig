const std = @import("std");
const ray = @import("raylib.zig");
const map = @import("map.zig");

pub fn main() void {
    ray.InitWindow(320, 240, "推箱子");
    defer ray.CloseWindow();

    // 初始化地图
    var state: [map.stageLength]map.MapItem = undefined;
    map.init(&state);
    defer map.deinit();

    const stdin = std.io.getStdIn().reader();

    while (true) {

        // 画出游戏地图
        ray.BeginDrawing();
        ray.ClearBackground(ray.WHITE);

        map.draw(&state);

        ray.EndDrawing();

        // 检查游戏胜利条件
        if (checkClear(&state)) break;

        std.debug.print("a:left d:right w:up s:down. command?\n", .{});
        // 获取用户输入
        const char = inputChar(stdin);
        // 根据输入更新游戏地图
        update(&state, char);
    }

    // 游戏胜利
    std.debug.print("Congratulation's! you win.\n", .{});
}

fn checkClear(stage: []map.MapItem) bool {
    for (stage) |value| {
        if (value == map.MapItem.BLOCK) {
            return false;
        }
    }
    return true;
}

fn inputChar(reader: anytype) ?u8 {
    var buffer: [2]u8 = undefined;
    const input = reader.readUntilDelimiterOrEof(buffer[0..], '\n') //
    catch null orelse return null;
    return if (input.len != 1) null else input[0];
}

fn update(state: []map.MapItem, input: ?u8) void {
    const char = input orelse return;

    // 操作角色移动的距离
    const delta: isize = switch (char) {
        'w' => -map.stageWidth,
        's' => map.stageWidth,
        'd' => 1,
        'a' => -1,
        else => return,
    };

    // 角色当前位置
    const currentIndex = for (state, 0..) |value, index| {
        if (value == .MAN or value == .MAN_ON_GOAL) break index;
    } else return;

    const index = @as(isize, @intCast(currentIndex)) + delta;
    if (index < 0 or index > map.stageLength) return;

    // 角色欲前往的目的地
    const destIndex = @as(usize, @intCast(index));
    updatePlayer(state, currentIndex, destIndex, delta);
}

fn updatePlayer(state: []map.MapItem, current: usize, dest: usize, delta: isize) void {
    if (state[dest] == .SPACE or state[dest] == .GOAL) {
        // 如果是空地或者目标地，则可以移动
        state[dest] = if (state[dest] == .GOAL) .MAN_ON_GOAL else .MAN;
        state[current] = if (state[current] == .MAN_ON_GOAL) .GOAL else .SPACE;
    } else if (state[dest] == .BLOCK or state[dest] == .BLOCK_ON_GOAL) {
        //  如果是箱子或者目的地上的箱子，需要考虑该方向上的第二个位置
        const index = @as(isize, @intCast(dest)) + delta;
        if (index < 0 or index > map.stageLength) return;

        const next = @as(usize, @intCast(index));
        if (state[next] == .SPACE or state[next] == .GOAL) {
            state[next] = if (state[next] == .GOAL) .BLOCK_ON_GOAL else .BLOCK;
            state[dest] = if (state[dest] == .BLOCK_ON_GOAL) .MAN_ON_GOAL else .MAN;
            state[current] = if (state[current] == .MAN_ON_GOAL) .GOAL else .SPACE;
        }
    }
}
