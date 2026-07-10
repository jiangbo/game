const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;

const battle = @import("battle.zig");
const player = @import("player.zig");

pub const State = enum { normal, hurt, dead };
const Enemy = struct {
    position: zhu.Vector2,
    animation: zhu.graphics.Animation,
    stats: battle.Stats = .{},
};
const normalFrames = zhu.graphics.framesX(4, .xy(32, 32), 0.2);
const deadFrames = zhu.graphics.framesX(8, .xy(32, 32), 0.1);
const maxSpeed = 100;
pub const size: zhu.Vector2 = .xy(64, 64);

pub var enemies: std.ArrayList(Enemy) = .empty;
pub var animations: zhu.graphics.EnumAnimation(State) = undefined;
const spawnFrames = zhu.graphics.framesX(11, .xy(64, 64), 0.1);
var spawnAnimation: zhu.graphics.Animation = undefined;
var spawnTimer: zhu.Timer = .init(3); // 三秒生成一批敌人
var spawnEnemies: [10]Enemy = undefined; // 一次生成 10 个敌人
var allocator: zhu.Allocator = undefined;

pub fn init(allocator_: zhu.Allocator) void {
    allocator = allocator_;

    var image = zhu.getImage("sprite/ghost-Sheet.png").?;
    animations.set(.normal, .init(image, .xy(32, 32), &normalFrames));
    image = zhu.getImage("sprite/ghostHurt-Sheet.png").?;
    animations.set(.hurt, .init(image, .xy(32, 32), &normalFrames));
    animations.getPtr(.hurt).loop = false;
    image = zhu.getImage("sprite/ghostDead-Sheet.png").?;
    animations.set(.dead, .init(image, .xy(32, 32), &deadFrames));
    animations.getPtr(.dead).loop = false;

    for (&animations.values, 0..) |*animation, i| {
        animation.extend = @intCast(i);
    }

    const spawnImage = zhu.getImage("effect/184_3.png").?;
    spawnAnimation = .initFinished(spawnImage, .xy(64, 64), &spawnFrames);
    spawnAnimation.loop = false;
}

pub fn enter() void {
    spawnTimer.elapsed = 0;
    spawnAnimation.stop();
    enemies.clearRetainingCapacity();
}

pub fn deinit() void {
    enemies.deinit(allocator.raw);
}

pub fn update(delta: f32) void {

    // 敌人的动画处理
    var iterator = std.mem.reverseIterator(enemies.items);
    while (iterator.nextPtr()) |enemy| {
        const state = enemy.animation.getEnumExtend(State);
        switch (state) {
            .normal => _ = enemy.animation.update(delta),
            .hurt => if (enemy.animation.update(delta) == .end) {
                enemy.animation = animations.get(.normal);
            },
            .dead => if (enemy.animation.update(delta) == .end) {
                _ = enemies.swapRemove(iterator.index);
            },
        }
    }
    if (player.stats.health == 0) return;

    if (spawnTimer.updateLooped(delta)) {
        spawnAnimation.reset();
        doSpawnEnemies();
    }

    if (spawnAnimation.update(delta) == .end) {
        enemies.appendSlice(allocator.raw, &spawnEnemies) catch unreachable;
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
    zhu.audio.playSound("sound/silly-ghost-sound-242342.ogg");
    for (&spawnEnemies) |*enemy| {
        const windowPos: zhu.Vector2 = .{
            .x = zhu.random.float(0, zhu.window.size.x),
            .y = zhu.random.float(0, zhu.window.size.y),
        };
        enemy.position = zhu.camera.toWorld(windowPos);
        enemy.stats = .{};
        enemy.animation = animations.get(.normal);
        const len = normalFrames.len;
        enemy.animation.index = zhu.random.int(u8, 0, @intCast(len));
    }
}

pub fn draw() void {
    if (spawnAnimation.isRunning()) {
        const image = spawnAnimation.subImage();
        for (&spawnEnemies) |enemy| {
            batch.drawImage(image, enemy.position, .{
                .size = size,
                .anchor = .center,
            });
        }
    }

    for (enemies.items) |enemy| {
        const image = enemy.animation.subImage();
        batch.drawImage(image, enemy.position, .{
            .size = size,
            .anchor = .center,
        });

        const max = enemy.stats.maxHealth;
        const percent = zhu.math.percentInt(enemy.stats.health, max);
        const pos = enemy.position.sub(.xy(32, 32)).addY(size.y - 10);

        var color: zhu.Color = .rgb(255, 165, 0);
        if (percent > 0.7) color = .green; // 健康
        if (percent < 0.3) color = .red; // 危险
        batch.drawRectBorder(.init(pos, .xy(size.x, 10)), 1, color);
        const rect: zhu.Rect = .init(pos, .xy(size.x * percent, 10));
        batch.drawRect(rect, .{ .color = color });
    }
}
