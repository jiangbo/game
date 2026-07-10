const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;

const menu = @import("menu.zig");
const scene = @import("scene.zig");

const Background = struct {
    image: zhu.graphics.Image,
    offset: f32 = 0,

    fn update(self: *Background, delta: f32, speed: f32) void {
        self.offset -= speed * delta;
        if (self.offset > 0) self.offset -= self.image.size.x;
    }

    fn draw(self: *const Background, y: f32) void {
        // 填满 X 轴
        var x: f32 = self.offset;
        while (x < zhu.window.size.x) : (x += self.image.size.x) {
            zhu.batch.drawImage(self.image, .xy(@round(x), y), .{});
        }
    }
};

var far: Background = undefined;
var mid: Background = undefined;
var showHelp: bool = false;

pub fn init() void {
    far = .{ .image = zhu.getImage("textures/Layers/back.png").? };
    mid = .{ .image = zhu.getImage("textures/Layers/middle.png").? };

    zhu.audio.playMusic("audio/platformer_level03_loop.ogg");
    menu.menuIndex = 0;
}

pub fn update(delta: f32) void {
    far.update(delta, 20);
    mid.update(delta, 60);

    if (showHelp) {
        if (zhu.key.pressed(.ESCAPE) or zhu.mouse.pressed(.LEFT)) {
            showHelp = false;
        }
        return;
    }

    if (menu.update()) |event| {
        switch (event) {
            0 => scene.start(), // 开始游戏
            1 => scene.load(), // 加载存档
            2 => showHelp = true, // 显示帮助
            3 => zhu.window.exit(), // 退出游戏
            else => unreachable,
        }
    }
}

pub fn draw() void {
    far.draw(0);
    mid.draw(96);

    const center = zhu.window.size.scale(0.5);
    const titleImage = zhu.getImage("textures/UI/title-screen.png").?;
    batch.drawImage(titleImage, center.addY(-50), .{
        .scale = .xy(2, 2),
        .anchor = .center,
    });

    menu.draw();
    // 底部信息栏
    const strPos: zhu.Vector2 = .xy(center.x, zhu.window.size.y - 26);
    zhu.text.draw("SunnyLand Credits: XXX - 2025", strPos, .{
        .anchor = .center,
        .color = .rgba(0.8, 0.8, 0.8, 1),
    });
    if (!showHelp) return;

    // 绘制帮助界面
    const helpImage = zhu.getImage("textures/UI/instructions.png").?;
    batch.drawImage(helpImage, center, .{
        .scale = .xy(2, 2),
        .anchor = .center,
    });
}
