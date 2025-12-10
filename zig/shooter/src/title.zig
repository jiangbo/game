const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const text = zhu.text;

const scene = @import("scene.zig");

var timer: window.Timer = .init(1); // 闪烁的定时器
var blink: bool = true;

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.J)) scene.restart();

    // 计时器闪烁
    if (timer.isFinishedAfterUpdate(delta)) {
        blink = !blink;
        timer.elapsed = 0;
    }
}

pub fn draw() void {
    window.drawCenter("太空战机", 0.35, .{ .size = 72, .spacing = 20 });
    if (blink) window.drawCenter("按J键开始游戏", 0.8, .{ .spacing = 5 });
}
