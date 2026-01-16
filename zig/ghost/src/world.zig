const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;

const player = @import("player.zig");
const enemy = @import("enemy.zig");
const battle = @import("battle.zig");

pub var paused: bool = false;
pub var worldSize: zhu.Vector2 = undefined; // 世界大小
var mouse: zhu.window.Cursor = .CUSTOM_1;
var mouseTimer: zhu.window.Timer = .init(0.3); // 鼠标切换时间

pub fn init() void {
    worldSize = zhu.window.logicSize.scale(3); // 设置世界大小

    player.init(worldSize.scale(0.5)); // 将玩家移动到世界中心
    enemy.init();
    battle.init();
}

pub fn deinit() void {
    enemy.deinit();
    battle.saveHighScore();
}

pub fn enter() void {
    zhu.window.bindAndUseMouseIcon("assets/29.png", .{
        .cursor = .CUSTOM_2,
        .offset = .{ .x = 16, .y = 16 },
    });
    zhu.window.bindMouseIcon("assets/30.png", .{
        .cursor = .CUSTOM_3,
        .offset = .{ .x = 16, .y = 16 },
    });

    zhu.audio.playMusic("assets/bgm/OhMyGhost.ogg");
    zhu.audio.paused = false;

    player.enter(worldSize.scale(0.5));
    enemy.enter();
    battle.enter();
}

pub fn update(delta: f32) void {
    if (mouseTimer.isFinishedLoopUpdate(delta)) {
        mouse = if (mouse == .CUSTOM_2) .CUSTOM_3 else .CUSTOM_2;
        zhu.window.useMouseIcon(mouse);
    }

    if (zhu.window.isKeyPress(.SPACE)) togglePause();

    if (!paused) {
        player.update(delta, worldSize);
        cameraFollow(player.position);
        enemy.update(delta);
    }
    battle.update(delta);
}

pub fn togglePause() void {
    paused = !paused;
    zhu.audio.pauseMusic();
}

fn cameraFollow(pos: zhu.Vector2) void {
    // const scaleSize = window.logicSize.div(camera.scale);
    // const half = scaleSize.scale(0.5);
    const max = worldSize.sub(zhu.window.logicSize).max(.zero);
    const halfWindowSize = zhu.window.logicSize.scale(0.5);
    const square: zhu.Vector2 = .square(30);
    camera.position = pos.sub(halfWindowSize);
    camera.position.clamp(square.scale(-1), max.add(square));
}

pub fn draw() void {
    const gridColor = zhu.graphics.Color.midGray;
    const area = zhu.Rect.init(.zero, worldSize);
    drawGrid(area, 80, gridColor);
    camera.drawRectBorder(area, 10, .white);

    enemy.draw(); // 敌人绘制
    player.draw(); // 玩家绘制
    battle.draw(); // 战斗绘制

    camera.mode = .local;
    defer camera.mode = .world;
    battle.drawUI();
}

fn drawGrid(area: zhu.Rect, width: f32, lineColor: zhu.Color) void {
    const max = area.max();
    const color = camera.LineOption{ .color = lineColor };

    var min = area.min;
    while (min.x < max.x) : (min.x += width) {
        camera.drawAxisLine(min, .xy(min.x, max.y), color);
    }

    min = area.min;
    while (min.y < max.y) : (min.y += width) {
        camera.drawAxisLine(min, .xy(max.x, min.y), color);
    }
}
