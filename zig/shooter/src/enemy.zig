const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;

const player = @import("player.zig");

const Enemy = struct {
    position: gfx.Vector, // 敌机的位置
    shotTime: u64 = 0, // 敌机开火的时间
    health: u8 = 2, // 敌机的生命值
};

const Bullet = struct {
    position: gfx.Vector, // 子弹的位置
    direction: gfx.Vector, // 子弹的方向
};

const ENEMY_SPEED = 150; // 敌机的移动速度
const BULLET_SPEED = 400; // 子弹的移动速度
const SHOOT_INTERVAL = 2 * std.time.ns_per_s; // 敌机开火间隔

var texture: gfx.Texture = undefined; // 敌机的纹理
pub var size: gfx.Vector = undefined; // 敌机的大小

pub var enemies: std.ArrayList(Enemy) = .empty;
var spawnTimer: window.Timer = .init(1); // 生成敌机的定时器

var bulletTexture: gfx.Texture = undefined; // 子弹的纹理
var bulletSize: gfx.Vector = undefined; // 子弹的大小
var bullets: std.ArrayList(Bullet) = .empty;
var bulletBound: gfx.Rect = undefined; // 子弹的边界

pub fn init() void {
    texture = gfx.loadTexture("assets/image/insect-2.png", .init(182, 160));
    size = texture.size().scale(0.25);

    bulletTexture = gfx.loadTexture("assets/image/bullet-1.png", .init(14, 42));
    bulletSize = bulletTexture.size().scale(0.5);

    // 子弹的边界框，超出就可以删除了。
    bulletBound = .init(bulletSize.scale(-1), window.logicSize);
}

pub fn restart() void {
    enemies.clearRetainingCapacity();
    bullets.clearRetainingCapacity();
}

pub fn update(delta: f32) void {
    if (spawnTimer.isFinishedAfterUpdate(delta)) { // 每秒生成一个
        spawnTimer.elapsed = 0;
        spawnEnemy();
    }

    const shotTime = window.relativeTime() -| SHOOT_INTERVAL;
    var iterator = std.mem.reverseIterator(enemies.items);
    while (iterator.nextPtr()) |enemy| {
        enemy.position.y += ENEMY_SPEED * delta; // 敌机向下移动
        if (enemy.position.y > window.logicSize.y) {
            // 移动到屏幕外了，删除
            _ = enemies.swapRemove(iterator.index);
        } else if (enemy.shotTime < shotTime) {
            // 到达开火时间
            enemy.shotTime = window.relativeTime();
            spawnBullet(enemy);
            zhu.audio.playSound("assets/sound/xs_laser.ogg");
        }
    }

    updateBullets(delta);
}

fn spawnEnemy() void {
    // 在 X 轴上随机生成敌机，Y 固定。
    const x = zhu.randomF32(0, window.logicSize.x - size.x);
    enemies.append(window.allocator, .{
        // Y 刚好让敌机出现在屏幕上方的外面
        .position = .init(x, -size.y),
        .shotTime = window.relativeTime(),
    }) catch unreachable;
}

fn spawnBullet(enemy: *Enemy) void {
    // 子弹出现在敌机的中心的位置，并且子弹中心和敌机的中心一样。
    const offset = size.sub(bulletSize).scale(0.5);
    const pos = enemy.position.add(offset);
    // 子弹的中心位置，是不是可以考虑子弹就是一个点，位置就是中心位置？
    const center = gfx.Rect.init(pos, bulletSize).center();
    bullets.append(window.allocator, .{
        .position = pos,
        // 子弹的方向应该是子弹的中心指向角色的中心
        .direction = player.center().sub(center).normalize(),
    }) catch unreachable;
}

fn updateBullets(delta: f32) void {
    var iterator = std.mem.reverseIterator(bullets.items);
    while (iterator.nextPtr()) |bullet| {
        const offset = bullet.direction.scale(BULLET_SPEED * delta);
        bullet.position = bullet.position.add(offset);
        if (!bulletBound.contains(bullet.position)) {
            // 移动到屏幕外了，删除
            _ = bullets.swapRemove(iterator.index);
            continue;
        }
        // 检测是否击中玩家
        const center = bullet.position.add(bulletSize.scale(0.5));
        if (player.collidePlayer(center)) {
            _ = bullets.swapRemove(iterator.index);
        }
    }
}

// 图片方向向下为正方向，所以需要减去半 π
const halfPi: f32 = @as(f32, std.math.pi) / 2;

pub fn draw() void {
    // 绘制子弹
    for (bullets.items) |bullet| {
        camera.drawOption(bulletTexture, bullet.position, .{
            .size = bulletSize,
            .radian = bullet.direction.atan2() - halfPi,
        });
    }
    // 绘制敌机
    for (enemies.items) |enemy| {
        camera.drawOption(texture, enemy.position, .{ .size = size });
    }
}

pub fn deinit() void {
    enemies.deinit(window.allocator);
    bullets.deinit(window.allocator);
}
