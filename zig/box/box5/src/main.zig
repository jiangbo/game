const std = @import("std");
const ray = @import("raylib.zig");
const map = @import("map.zig");
const state = @import("state.zig");

const screenWidth = 320;
const screenHeight = 240;

pub fn main() void {
    ray.InitWindow(screenWidth, screenHeight, "推箱子");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    ray.SetExitKey(ray.KEY_NULL);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var currentState = state.State.init(gpa.allocator());
    defer currentState.deinit();

    while (!ray.WindowShouldClose()) {
        currentState.update();
        currentState.draw();
    }
}
