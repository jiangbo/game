const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");
const state = @import("state.zig");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    engine.init(gpa.allocator(), 640, 480, "炸弹人");
    defer engine.deinit();

    const sound = engine.Sound.init("data/sound/charara.wav");
    defer sound.deinit();
    sound.play();

    map.init();
    defer map.deinit();

    var mainState = state.State.init();
    defer mainState.deinit();

    while (engine.shouldContinue()) {
        mainState.update();
        mainState.draw();
    }
}
