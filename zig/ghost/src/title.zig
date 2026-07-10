const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;

const scene = @import("scene.zig");
const menu = @import("menu.zig");
const battle = @import("battle.zig");

const creditsText = @embedFile("zon/credits.txt");
var showCredits: bool = false;
var background: zhu.Image = undefined;

pub fn init() void {
    zhu.window.useCursor("pointer_c_shaded.png", .{});
    background = zhu.getImage("UI/Textfield_01.png").?;
    enter();
    var buffer: [4]u8 = undefined;
    const bytes = zhu.window.readBuffer("high.save", &buffer) catch {
        battle.highScore = 0;
        return;
    };
    battle.highScore = std.mem.bytesToValue(u32, bytes);
}

pub fn enter() void {
    zhu.camera.main = .window;
    zhu.window.setCursor(.DEFAULT);
    zhu.audio.playMusic("bgm/Spooky music.ogg");
    menu.menuIndex = 0;
    battle.saveHighScore();
}

var time: f32 = 0;
pub fn update(delta: f32) void {
    time += delta;

    if (showCredits) {
        if (zhu.key.changed or zhu.mouse.changed) showCredits = false;
        return;
    }

    if (menu.update()) |event| {
        // 播放点击音效
        zhu.audio.playSound("sound/UI_button08.ogg");
        switch (event) {
            0 => scene.changeScene(.world), // 开始游戏
            1 => showCredits = !showCredits, // 显示版权信息
            2 => zhu.window.exit(), // 退出游戏
            else => unreachable,
        }
    }
}

pub fn draw() void {

    // 边框
    var size = zhu.window.size.sub(.xy(60, 60));
    batch.drawRectBorder(.init(.xy(30, 30), size), 10, .{
        .r = 0.5 + @sin(time * 0.9) * 0.5,
        .g = 0.5 + @sin(time * 0.8) * 0.5,
        .b = 0.5 + @sin(time * 0.7) * 0.5,
        .a = 1.0,
    });

    // 标题
    const basicPos = zhu.Vector2.xy(320, 100); // 定位位置
    size = zhu.window.size.div(.xy(2, 3));

    // 先绘制图片，再绘制文字，减少批量绘制次数
    batch.drawImage(background, basicPos, .{ .size = size });
    if (showCredits) {
        const creditsSize = zhu.Vector2.xy(555, 600);
        const creditsPos = basicPos.addXY(45, -40);
        batch.drawImage(background, creditsPos, .{ .size = creditsSize });
        zhu.text.draw(creditsText, creditsPos.addXY(20, 40), .{
            .scale = zhu.text.sizeToScale(16),
        });
        return;
    }

    menu.draw();

    batch.drawImage(background, basicPos.addXY(200, 285), .{
        .size = .xy(232, 60),
    });

    var pos = basicPos.addXY(150, 80);
    zhu.text.draw("幽 灵 逃 生", pos, .{
        .scale = zhu.text.sizeToScale(64),
    });

    pos = basicPos.addXY(220, 300);
    zhu.text.draw("最高分：", pos, .{});
    zhu.text.drawNumber(battle.highScore, pos.addX(125), .{});
}
