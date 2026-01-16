const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;

const battle = @import("battle.zig");
const player = @import("player.zig");

pub const State = enum { normal, hurt, dead };
const Enemy = struct {
    position: zhu.Vector2,
    animation: zhu.graphics.FrameAnimation,
    stats: battle.Stats = .{},
};
const normalFrames = zhu.graphics.framesX(4, .xy(32, 32), 0.2);
const deadFrames = zhu.graphics.framesX(8, .xy(32, 32), 0.1);
const maxSpeed = 100;
const circle = zhu.graphics.imageId("circle.png"); // 显示碰撞范围
pub const size = deadFrames[0].area.size.scale(2);

pub var enemies: std.ArrayList(Enemy) = .empty;
pub var animations: zhu.graphics.EnumFrameAnimation(State) = undefined;
const spawnFrames = zhu.graphics.framesX(11, .xy(64, 64), 0.1);
var spawnAnimation: zhu.graphics.FrameAnimation = undefined;
var spawnTimer: zhu.window.Timer = .init(3); // 三秒生成一批敌人
var spawnEnemies: [10]Enemy = undefined; // 一次生成 10 个敌人

pub fn init() void {
    var image = zhu.graphics.getImage("sprite/ghost-Sheet.png");
    animations.set(.normal, .init(image, &normalFrames));
    image = zhu.graphics.getImage("sprite/ghostHurt-Sheet.png");
    animations.set(.hurt, .init(image, &normalFrames)); // 受伤和普通动画一样
    image = zhu.graphics.getImage("sprite/ghostDead-Sheet.png");
    animations.set(.dead, .init(image, &deadFrames));

    for (&animations.values, 0..) |*a, i| a.state = @intCast(i);

    const spawnImage = zhu.graphics.getImage("effect/184_3.png");
    spawnAnimation = .initFinished(spawnImage, &spawnFrames);
}

pub fn enter() void {
    spawnTimer.elapsed = 0;
    spawnAnimation.stop();
    enemies.clearRetainingCapacity();
}

pub fn deinit() void {
    enemies.deinit(zhu.window.allocator);
}

pub fn update(delta: f32) void {

    // 敌人的动画处理
    var iterator = std.mem.reverseIterator(enemies.items);
    while (iterator.nextPtr()) |enemy| {
        const state = enemy.animation.getEnumState(State);
        switch (state) {
            .normal => enemy.animation.loopUpdate(delta),
            .hurt => if (enemy.animation.isFinishedOnceUpdate(delta)) {
                enemy.animation = animations.get(.normal);
            },
            .dead => if (enemy.animation.isFinishedOnceUpdate(delta)) {
                _ = enemies.swapRemove(iterator.index);
            },
        }
    }
    if (player.stats.health == 0) return;

    if (spawnTimer.isFinishedLoopUpdate(delta)) {
        spawnAnimation.reset();
        doSpawnEnemies();
    }

    spawnAnimation.onceUpdate(delta);
    if (spawnAnimation.isJustFinished()) {
        enemies.appendSlice(zhu.window.allocator, &spawnEnemies) catch unreachable;
    }

    for (enemies.items) |*enemy| {
        const dir = player.position.sub(enemy.position);
        const distance = dir.normalize().scale(maxSpeed * delta);
        enemy.position = enemy.position.add(distance);

        const len = (player.size.x + size.x) * 0.5;
        const len2 = player.position.sub(enemy.position).length2();
        if (len2 < len * len) player.hurt(enemy.stats.attack);
    }
}

fn doSpawnEnemies() void {
    // 播放敌人生成音效
    zhu.audio.playSound("assets/sound/silly-ghost-sound-242342.ogg");
    for (&spawnEnemies) |*enemy| {
        const windowPos: zhu.Vector2 = .{
            .x = zhu.randomF32(0, zhu.window.logicSize.x),
            .y = zhu.randomF32(0, zhu.window.logicSize.y),
        };
        enemy.position = camera.toWorld(windowPos);
        enemy.stats = .{};
        enemy.animation = animations.get(.normal);
        const len = normalFrames.len;
        enemy.animation.index = zhu.randomInt(u8, 0, len);
    }
}

pub fn draw() void {
    if (spawnAnimation.isRunning()) {
        const image = spawnAnimation.currentImage();
        for (&spawnEnemies) |enemy| {
            camera.drawImage(image, enemy.position, .{
                .size = size,
                .anchor = .center,
            });
        }
    }

    for (enemies.items) |enemy| {
        const image = enemy.animation.currentImage();
        camera.drawImage(image, enemy.position, .{
            .size = size,
            .anchor = .center,
        });

        const max = enemy.stats.maxHealth;
        const percent = zhu.math.percentInt(enemy.stats.health, max);
        const pos = enemy.position.sub(deadFrames[0].area.size)
            .addY(size.y - 10);

        var color: zhu.Color = .rgb(255, 165, 0);
        if (percent > 0.7) color = .green; // 健康
        if (percent < 0.3) color = .red; // 危险
        camera.drawRectBorder(.init(pos, .xy(size.x, 10)), 1, color);
        const rect: zhu.Rect = .init(pos, .xy(size.x * percent, 10));
        camera.drawRect(rect, .{ .color = color });
    }
}
