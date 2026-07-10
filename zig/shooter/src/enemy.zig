const std = @import("std");
const zhu = @import("zhu");

const player = @import("player.zig");

pub const Enemy = struct {
    position: zhu.Vector2, // 敌机的位置
    shotTimer: zhu.Timer = .init(2), // 敌机开火计时器
    health: u8 = 2, // 敌机的生命值
};

const Bullet = struct {
    position: zhu.Vector2, // 子弹的位置
    direction: zhu.Vector2, // 子弹的方向
};

var allocator: std.mem.Allocator = undefined;
var image: zhu.Image = undefined; // 敌机的图片
pub var size: zhu.Vector2 = undefined; // 敌机的大小

pub var enemies: std.ArrayList(Enemy) = .empty;
var spawnTimer: zhu.Timer = .init(1); // 生成敌机的定时器

var bulletImage: zhu.Image = undefined; // 子弹的图片
var bulletSize: zhu.Vector2 = undefined; // 子弹的大小
var bullets: std.ArrayList(Bullet) = .empty;
var bulletBound: zhu.Rect = undefined; // 子弹的边界

pub fn init(allocator_: std.mem.Allocator) void {
    allocator = allocator_;
    image = zhu.getImage("image/insect-2.png").?;
    size = image.size.scale(0.25);

    bulletImage = zhu.getImage("image/bullet-1.png").?;
    bulletSize = bulletImage.size.scale(0.5);

    // 子弹的边界框，超出就可以删除。
    bulletBound = .init(bulletSize.scale(-1), zhu.window.size);
}

pub fn restart() void {
    enemies.clearRetainingCapacity();
    bullets.clearRetainingCapacity();
    spawnTimer.restart();
}

pub fn update(delta: f32) void {
    if (spawnTimer.updateFinished(delta)) {
        spawnTimer.restart();
        spawnEnemy();
    }

    var iterator = std.mem.reverseIterator(enemies.items);
    while (iterator.nextPtr()) |enemy| {
        enemy.position.y += 150 * delta;
        if (enemy.position.y > zhu.window.size.y) {
            _ = enemies.swapRemove(iterator.index);
        } else if (enemy.shotTimer.updateFinished(delta)) {
            enemy.shotTimer.restart();
            spawnBullet(enemy);
            zhu.audio.playSound("sound/xs_laser.ogg");
        }
    }

    updateBullets(delta);
}

fn spawnEnemy() void {
    const x = zhu.random.float(0, zhu.window.size.x - size.x);
    enemies.append(allocator, .{
        .position = .xy(x, -size.y),
    }) catch @panic("enemy oom");
}

fn spawnBullet(enemy: *Enemy) void {
    const offset = size.sub(bulletSize).scale(0.5);
    const pos = enemy.position.add(offset);
    const center = zhu.Rect.init(pos, bulletSize).center();
    bullets.append(allocator, .{
        .position = pos,
        .direction = player.center().sub(center).normalize(),
    }) catch @panic("enemy bullet oom");
}

fn updateBullets(delta: f32) void {
    var iterator = std.mem.reverseIterator(bullets.items);
    while (iterator.nextPtr()) |bullet| {
        const offset = bullet.direction.scale(400 * delta);
        bullet.position = bullet.position.add(offset);
        if (!bulletBound.contains(bullet.position)) {
            _ = bullets.swapRemove(iterator.index);
            continue;
        }

        const center = bullet.position.add(bulletSize.scale(0.5));
        if (player.collidePlayer(center)) {
            _ = bullets.swapRemove(iterator.index);
        }
    }
}

pub fn draw() void {
    for (bullets.items) |bullet| {
        zhu.batch.drawImage(bulletImage, bullet.position, .{
            .size = bulletSize,
            .radian = bullet.direction.atan2() - @as(f32, std.math.pi) / 2,
        });
    }

    for (enemies.items) |enemy| {
        zhu.batch.drawImage(image, enemy.position, .{ .size = size });
    }
}

pub fn deinit() void {
    enemies.deinit(allocator);
    bullets.deinit(allocator);
}
