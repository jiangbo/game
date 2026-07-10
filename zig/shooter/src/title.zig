const zhu = @import("zhu");

const scene = @import("scene.zig");

var timer: zhu.Timer = .init(1); // 闪烁的定时器
var blink: bool = true;

pub fn update(delta: f32) void {
    if (zhu.key.released(.J)) scene.restart();

    if (timer.updateFinished(delta)) {
        blink = !blink;
        timer.restart();
    }
}

pub fn draw() void {
    zhu.window.drawCenter("太空战机", 0.35, .{
        .scale = zhu.text.sizeToScale(72),
        .spacing = 20,
    });

    if (blink) {
        zhu.window.drawCenter("按J键开始游戏", 0.8, .{
            .spacing = 5,
        });
    }
}
