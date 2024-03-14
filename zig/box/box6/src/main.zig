const std = @import("std");
const engine = @import("engine.zig");
const state = @import("state.zig");

pub fn main() void {
    engine.init(320, 240, "推箱子");
    defer engine.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var mainState = state.State.init(gpa.allocator());
    defer mainState.deinit();

    while (engine.shoudContinue()) {
        mainState.update();
        mainState.draw();
    }
}
