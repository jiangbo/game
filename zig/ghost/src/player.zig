const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const window = zhu.window;

const battle = @import("battle.zig");
const menu = @import("menu.zig");

const maxSpeed = 500;
const frameSize = zhu.Vector2.xy(48, 48);
const deadFrameSize = zhu.Vector2.xy(64, 64);
const frames = zhu.graphics.framesX(8, frameSize, 0.1);
const deadFrames = zhu.graphics.framesX(17, deadFrameSize, 0.1);
pub const size = frameSize;
const Status = enum { idle, move };

var idleImage: zhu.graphics.Image = undefined;
var moveImage: zhu.graphics.Image = undefined;

pub var position: zhu.Vector2 = undefined;
pub var stats: battle.Stats = .{};

var hurtTimer: zhu.Timer = .init(1.5); // 无敌时间
var velocity: zhu.Vector2 = .zero;
var velocityTimer: zhu.Timer = .init(0.03);
var animation: zhu.Animation = undefined;
var deadAnimation: zhu.Animation = undefined;
var status: Status = .idle;

pub fn init() void {
    idleImage = zhu.getImage("sprite/ghost-idle.png").?;
    moveImage = zhu.getImage("sprite/ghost-move.png").?;

    const deadImage = zhu.getImage("effect/1764.png").?;
    deadAnimation = .init(deadImage, deadFrameSize, &deadFrames);
    deadAnimation.loop = false;

    animation = .init(idleImage, frameSize, &frames);
    position = zhu.camera.bound.scale(0.5);
}

pub fn enter() void {
    stats.health = 100;
    position = zhu.camera.bound.scale(0.5); // 将玩家移动到世界中心;
    velocity = .zero;
    status = .idle;
    animation.reset();
    deadAnimation.reset();
    hurtTimer.stop();
}

pub fn update(delta: f32) void {
    if (stats.health == 0) {
        // 角色已死亡
        if (deadAnimation.update(delta) == .end) menu.menuIndex = 2;
    }
    hurtTimer.update(delta);

    if (velocityTimer.updateLooped(delta)) {
        // 速度衰减不应该和帧率相关
        velocity = velocity.scale(0.9);
    }

    if (zhu.key.pressed(.A)) velocity.x = -maxSpeed;
    if (zhu.key.pressed(.D)) velocity.x = maxSpeed;
    if (zhu.key.pressed(.W)) velocity.y = -maxSpeed;
    if (zhu.key.pressed(.S)) velocity.y = maxSpeed;

    move(delta);
    position = position.clamp(.zero, zhu.camera.bound.sub(size));
    _ = animation.update(delta);
}

pub fn hurt(damage: u32) void {
    if (hurtTimer.isRunning()) return; // 受伤后的无敌时间

    stats.health -|= damage; // 扣除生命值
    hurtTimer.elapsed = 0; // 重置计时器
    if (stats.health == 0) {
        battle.saveHighScore();
        // 播放死亡音效
        zhu.audio.playSound("sound/female-scream-02-89290.ogg");
    } else {
        // 播放受伤音效
        zhu.audio.playSound("sound/hit-flesh-02-266309.ogg");
    }
}

fn move(delta: f32) void {
    position = position.add(velocity.scale(delta));

    const new: Status = if (velocity.length2() < 0.01) .idle else .move;
    if (new == status) return; // 状态未变化
    status = new;
    const source = if (new == .move) moveImage else idleImage;
    animation.image = source.sub(.init(.zero, frameSize));
}

pub fn draw() void {
    if (stats.health == 0) {
        if (!deadAnimation.isRunning()) return; // 动画结束不需要显示

        const image = deadAnimation.subImage();
        return batch.drawImage(image, position, .{
            .size = size.scale(2), // 和角色的显示区域一样大
            .anchor = .center,
        });
    }

    if (hurtTimer.isRunning() and hurtTimer.isEvenStep(0.2)) return;
    const image = animation.subImage();
    batch.drawImage(image, position, .{
        .size = size.scale(2),
        .anchor = .center,
        .uvRect = if (velocity.x < 0) image.uvFlip(true, false) else null,
    });
}
