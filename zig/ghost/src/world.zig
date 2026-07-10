const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;

const player = @import("player.zig");
const enemy = @import("enemy.zig");
const battle = @import("battle.zig");

pub var paused: bool = false;
var mouse: zhu.window.Cursor = .CUSTOM_1;
var mouseTimer: zhu.Timer = .init(0.3); // 鼠标切换时间

pub fn init(allocator: zhu.Allocator) void {
    zhu.camera.bound = zhu.window.size.scale(3); // 设置世界大小

    player.init();
    enemy.init(allocator);
    battle.init();
}

pub fn deinit() void {
    enemy.deinit();
    battle.saveHighScore();
}

pub fn enter() void {
    zhu.window.useCursor("29.png", .{
        .cursor = .CUSTOM_2,
        .offset = .{ .x = 16, .y = 16 },
    });
    zhu.window.loadCursor("30.png", .{
        .cursor = .CUSTOM_3,
        .offset = .{ .x = 16, .y = 16 },
    });

    zhu.audio.playMusic("bgm/OhMyGhost.ogg");
    zhu.audio.setMusicState(.playing);

    player.enter();
    enemy.enter();
    battle.enter();
}

pub fn update(delta: f32) void {
    if (mouseTimer.updateLooped(delta)) {
        mouse = if (mouse == .CUSTOM_2) .CUSTOM_3 else .CUSTOM_2;
        zhu.window.setCursor(mouse);
    }

    if (zhu.key.pressed(.SPACE)) togglePause();

    if (!paused) {
        player.update(delta);
        zhu.camera.directFollow(player.position);
        enemy.update(delta);
    }
    battle.update(delta);
}

pub fn togglePause() void {
    paused = !paused;
    zhu.audio.setMusicState(if (paused) .paused else .playing);
}

pub fn draw() void {
    const gridColor = zhu.graphics.Color.midGray;
    const area = zhu.Rect.init(.zero, zhu.camera.bound);
    drawGrid(area, 80, gridColor);
    batch.drawRectBorder(area, 10, .white);

    enemy.draw(); // 敌人绘制
    player.draw(); // 玩家绘制
    battle.draw(); // 战斗绘制

    zhu.camera.push(.window);
    defer zhu.camera.pop();
    battle.drawUI();
}

fn drawGrid(area: zhu.Rect, width: f32, lineColor: zhu.Color) void {
    const max = area.max();
    const color = batch.LineOption{ .color = lineColor };

    var min = area.min;
    while (min.x < max.x) : (min.x += width) {
        batch.drawAxisLine(min, .xy(min.x, max.y), color);
    }

    min = area.min;
    while (min.y < max.y) : (min.y += width) {
        batch.drawAxisLine(min, .xy(max.x, min.y), color);
    }
}
