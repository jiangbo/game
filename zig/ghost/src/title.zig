const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;

const scene = @import("scene.zig");
const menu = @import("menu.zig");
const battle = @import("battle.zig");

const background = zhu.graphics.imageId("UI/Textfield_01.png");

const creditsText = @embedFile("zon/credits.txt");
var showCredits: bool = false;

pub fn init() void {
    zhu.window.bindAndUseMouseIcon("assets/pointer_c_shaded.png", .{});
    enter();
    var buffer: [4]u8 = undefined;
    const bytes = zhu.window.readBuffer("high.save", &buffer) catch {
        battle.highScore = 0;
        return;
    };
    battle.highScore = std.mem.bytesToValue(u32, bytes);
}

pub fn enter() void {
    camera.position = .zero;
    zhu.window.useMouseIcon(.DEFAULT);
    zhu.audio.playMusic("assets/bgm/Spooky music.ogg");
    menu.menuIndex = 0;
    battle.saveHighScore();
}

var time: f32 = 0;
pub fn update(delta: f32) void {
    time += delta;

    if (showCredits) {
        if (zhu.window.isAnyRelease()) showCredits = false;
        return;
    }

    if (menu.update()) |event| {
        // 播放点击音效
        zhu.audio.playSound("assets/sound/UI_button08.ogg");
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
    var size = zhu.window.logicSize.sub(.xy(60, 60));
    camera.drawRectBorder(.init(.xy(30, 30), size), 10, .{
        .r = zhu.math.sinInt(u8, time * 0.9, 100, 255),
        .g = zhu.math.sinInt(u8, time * 0.8, 100, 255),
        .b = zhu.math.sinInt(u8, time * 0.7, 100, 255),
        .a = 255,
    });

    // 标题
    const basicPos = zhu.Vector2.xy(320, 100); // 定位位置
    size = zhu.window.logicSize.div(.xy(2, 3));

    // 先绘制图片，再绘制文字，减少批量绘制次数
    camera.drawOption(background, basicPos, .{ .size = size });
    if (showCredits) {
        const creditsSize = zhu.Vector2.xy(555, 600);
        const creditsPos = basicPos.addXY(45, -40);
        camera.drawOption(background, creditsPos, .{ .size = creditsSize });
        zhu.text.drawOption(creditsText, creditsPos.addXY(20, 40), .{
            .size = 16,
        });
        return;
    }

    menu.draw();

    camera.drawOption(background, basicPos.addXY(200, 285), .{
        .size = .xy(232, 60),
    });

    var pos = basicPos.addXY(150, 80);
    zhu.text.drawOption("幽 灵 逃 生", pos, .{ .size = 64 });

    pos = basicPos.addXY(220, 300);
    zhu.text.drawText("最高分：", pos);
    zhu.text.drawNumber(battle.highScore, pos.addX(125));
}
