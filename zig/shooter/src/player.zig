const std = @import("std");
const zhu = @import("zhu");

const enemy = @import("enemy.zig");
const item = @import("item.zig");
const scene = @import("scene.zig");

const Bullet = struct {
    position: zhu.Vector2, // 子弹的位置
    dead: bool = true, // 子弹是否死亡
};

var allocator: std.mem.Allocator = undefined;
var position: zhu.Vector2 = undefined; // 玩家的位置
var image: zhu.Image = undefined; // 玩家的图片
var size: zhu.Vector2 = undefined; // 玩家的尺寸
var health: u8 = undefined; // 玩家生命值

var bulletImage: zhu.Image = undefined; // 子弹的图片
var bulletSize: zhu.Vector2 = undefined; // 子弹的尺寸
var bullets: [10]Bullet = undefined; // 子弹数组

// 子弹发射的间隔，每 0.3 秒可以发射一次。
var bulletTimer: zhu.Timer = .init(0.3);

// 爆炸帧动画元数据。
const bombFrames: [9]zhu.graphics.Frame = blk: {
    var frames: [9]zhu.graphics.Frame = undefined;
    for (&frames, 0..) |*frame, i| {
        const x: f32 = @floatFromInt(32 * i);
        frame.offset = .xy(x, 0);
        frame.duration = 0.1;
    }
    break :blk frames;
};
var bombFrameAnimation: zhu.Animation = undefined;

const BombAnimation = struct {
    animation: zhu.Animation, // 爆炸动画
    center: zhu.Vector2, // 爆炸中心点
};
var bombAnimations: std.ArrayList(BombAnimation) = .empty;
var bombed: bool = false; // 玩家是否爆炸

var healthImage: zhu.Image = undefined; // 玩家生命值图片
pub var score: u32 = 0; // 玩家得分
var deadTimer: zhu.Timer = .init(3); // 玩家死亡计时器

pub fn init(allocator_: std.mem.Allocator) void {
    allocator = allocator_;

    image = zhu.getImage("image/SpaceShip.png").?;
    size = image.size.scale(0.25);

    bulletImage = zhu.getImage("image/laser-1.png").?;
    bulletSize = bulletImage.size.scale(0.25);

    for (&bullets) |*bullet| bullet.dead = true;

    const bombImage = zhu.getImage("effect/explosion.png").?;
    bombFrameAnimation = .init(bombImage, .xy(32, 32), &bombFrames);
    bombFrameAnimation.loop = false;

    healthImage = zhu.getImage("image/Health UI Black.png").?;

    item.init(allocator);
    restart();
}

pub fn restart() void {
    bombAnimations.clearRetainingCapacity();
    item.items.clearRetainingCapacity();
    position = zhu.window.size.sub(size).div(.xy(2, 1));
    bulletTimer.restart();
    deadTimer.restart();
    bombed = false;
    health = 3;
    score = 0;
}

pub fn update(delta: f32) void {
    item.update(delta);
    updateBullets(delta);

    var bombs = std.mem.reverseIterator(bombAnimations.items);
    while (bombs.nextPtr()) |bomb| {
        if (bomb.animation.update(delta) == .end) {
            _ = bombAnimations.swapRemove(bombs.index);
        }
    }

    if (health == 0) {
        if (deadTimer.updateFinished(delta)) {
            scene.currentScene = .end;
            scene.isTyping = true;
            zhu.audio.playMusic("music/06_Battle_in_Space_Intro.ogg");
        }

        if (!bombed) {
            bombed = true;
            addBombAnimation(center());
            zhu.audio.playSound("sound/explosion1.ogg");
        }
        return;
    }

    maybePickItem();

    const distance = 300 * delta;
    if (zhu.key.held(.A)) position.x -= distance;
    if (zhu.key.held(.D)) position.x += distance;
    if (zhu.key.held(.W)) position.y -= distance;
    if (zhu.key.held(.S)) position.y += distance;

    if (bulletTimer.updateFinished(delta) and zhu.key.held(.J)) {
        const pos = position.addX(size.x / 2).addX(-bulletSize.x / 2);
        for (&bullets) |*bullet| {
            if (bullet.dead) {
                bullet.* = .{ .position = pos, .dead = false };
                break;
            }
        }
        zhu.audio.playSound("sound/laser_shoot4.ogg");
        bulletTimer.restart();
    }

    position = position.clamp(.zero, zhu.window.size.sub(size));

    const playerRect = zhu.Rect.init(position, size);
    var iterator = std.mem.reverseIterator(enemy.enemies.items);
    while (iterator.nextPtr()) |ptr| {
        if (health == 0) break;

        const rect: zhu.Rect = .init(ptr.position, enemy.size);
        if (!rect.intersect(playerRect)) continue;

        health -= 1;
        _ = enemy.enemies.swapRemove(iterator.index);
        addBombAnimation(rect.center());
    }
}

fn maybePickItem() void {
    const playerRect = zhu.Rect.init(position, size);
    var iterator = std.mem.reverseIterator(item.items.items);
    while (iterator.nextPtr()) |ptr| {
        if (playerRect.contains(ptr.position)) {
            _ = item.items.swapRemove(iterator.index);
            if (health < 3) health += 1;
            score += 5;
            zhu.audio.playSound("sound/eff5.ogg");
        }
    }
}

fn updateBullets(delta: f32) void {
    for (&bullets) |*bullet| {
        if (bullet.dead) continue;

        bullet.position.y -= 600 * delta;
        if (bullet.position.y < -bulletSize.y) {
            bullet.dead = true;
            continue;
        }

        const bulletCenter = bullet.position.add(bulletSize.scale(0.5));
        if (collideEnemy(bulletCenter)) bullet.dead = true;
    }
}

fn addBombAnimation(bombCenter: zhu.Vector2) void {
    bombAnimations.append(allocator, .{
        .animation = bombFrameAnimation,
        .center = bombCenter,
    }) catch @panic("add bomb oom");
}

fn collideEnemy(bullet: zhu.Vector2) bool {
    var iterator = std.mem.reverseIterator(enemy.enemies.items);
    while (iterator.nextPtr()) |ptr| {
        const rect: zhu.Rect = .init(ptr.position, enemy.size);
        if (!rect.contains(bullet)) continue;

        ptr.health -|= 1;
        if (ptr.health == 0) {
            item.maybeDropItem(rect.center());
            _ = enemy.enemies.swapRemove(iterator.index);
            score += 10;
            addBombAnimation(rect.center());
            zhu.audio.playSound("sound/explosion3.ogg");
        }
        zhu.audio.playSound("sound/eff11.ogg");
        return true;
    }
    return false;
}

pub fn center() zhu.Vector2 {
    return zhu.Rect.init(position, size).center();
}

pub fn collidePlayer(enemyBulletPosition: zhu.Vector2) bool {
    if (health == 0) return false;

    const rect = zhu.Rect.init(position, size);
    if (rect.contains(enemyBulletPosition)) {
        health -= 1;
        return true;
    }
    return false;
}

pub fn draw() void {
    for (&bullets) |bullet| {
        if (bullet.dead) continue;
        zhu.batch.drawImage(bulletImage, bullet.position, .{
            .size = bulletSize,
        });
    }

    item.draw();

    if (health != 0) {
        zhu.batch.drawImage(image, position, .{ .size = size });
    }

    for (bombAnimations.items) |bomb| {
        const currentImage = bomb.animation.subImage();
        zhu.batch.drawImage(currentImage, bomb.center, .{
            .anchor = .center,
            .size = currentImage.size.scale(2),
        });
    }

    for (0..3) |index| {
        var color: zhu.Color = .rgba(0.4, 0.4, 0.4, 1);
        if (health > index) color = .white;

        const i: f32 = @floatFromInt(index);
        zhu.batch.drawImage(healthImage, .xy(10 + i * 40, 10), .{
            .color = color,
        });
    }

    var buffer: [50]u8 = undefined;
    const scoreText = zhu.format(&buffer, "SCORE:{}", .{score});
    const textSize = zhu.text.measure(scoreText, .{});
    const x = zhu.window.size.x - textSize.x - 10;
    zhu.text.draw(scoreText, .xy(x, 10), .{});
}

pub fn deinit() void {
    bombAnimations.deinit(allocator);
    item.deinit();
}
