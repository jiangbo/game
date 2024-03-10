const std = @import("std");
const ray = @import("raylib.zig");
const map = @import("map.zig");

const screenWidth = 320;
const screenHeight = 240;

pub fn main() void {
    ray.InitWindow(screenWidth, screenHeight, "推箱子");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    ray.SetExitKey(ray.KEY_NULL);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stage = map.Stage.init(allocator, 1) orelse return;
    defer stage.deinit();

    while (!ray.WindowShouldClose()) {

        // 根据输入更新游戏地图
        update(&stage);

        // 检查游戏胜利条件
        if (!stage.hasBlock()) break;

        // 画出游戏地图
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.WHITE);

        map.draw(stage);
        ray.DrawFPS(screenWidth - 80, 10);
    }

    // 游戏胜利
    std.debug.print("Congratulation's! you win.\n", .{});
}

fn update(stage: *map.Stage) void {
    // 操作角色移动的距离
    const delta: isize = switch (ray.GetKeyPressed()) {
        ray.KEY_W, ray.KEY_UP => -@as(isize, @intCast(stage.width)),
        ray.KEY_S, ray.KEY_DOWN => @as(isize, @intCast(stage.width)),
        ray.KEY_D, ray.KEY_RIGHT => 1,
        ray.KEY_A, ray.KEY_LEFT => -1,
        else => return,
    };

    const currentIndex = stage.playerIndex();
    const index = @as(isize, @intCast(currentIndex)) + delta;
    if (index < 0 or index > stage.width * stage.height) return;

    // 角色欲前往的目的地
    const destIndex = @as(usize, @intCast(index));
    updatePlayer(stage, currentIndex, destIndex, delta);
}

fn updatePlayer(stage: *map.Stage, current: usize, dest: usize, delta: isize) void {
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
