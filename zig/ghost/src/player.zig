const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;
const window = zhu.window;

const battle = @import("battle.zig");
const menu = @import("menu.zig");

const circle = zhu.graphics.imageId("circle.png"); // 显示碰撞范围
const maxSpeed = 500;
const frames = zhu.graphics.framesX(8, .xy(48, 48), 0.1);
const deadFrames = zhu.graphics.framesX(17, .xy(64, 64), 0.1);
pub const size = frames[0].area.size;
const Status = enum { idle, move };

var idleImage: zhu.graphics.Image = undefined;
var moveImage: zhu.graphics.Image = undefined;

pub var position: zhu.Vector2 = undefined;
pub var stats: battle.Stats = .{};

var hurtTimer: window.Timer = .init(1.5); // 无敌时间
var velocity: zhu.Vector2 = .zero;
var velocityTimer: window.Timer = .init(0.03);
var animation: zhu.graphics.FrameAnimation = undefined;
var deadAnimation: zhu.graphics.FrameAnimation = undefined;
var status: Status = .idle;

pub fn init(initPosition: zhu.Vector2) void {
    idleImage = zhu.graphics.getImage("sprite/ghost-idle.png");
    moveImage = zhu.graphics.getImage("sprite/ghost-move.png");

    const deadImage = zhu.graphics.getImage("effect/1764.png");
    deadAnimation = .init(deadImage, &deadFrames);

    animation = .init(idleImage, &frames);
    position = initPosition;
}

pub fn enter(initPosition: zhu.Vector2) void {
    stats.health = 100;
    position = initPosition; // 重置位置
    velocity = .zero;
    status = .idle;
    animation.reset();
    deadAnimation.reset();
    hurtTimer.stop();
}

pub fn update(delta: f32, worldSize: zhu.Vector2) void {
    if (stats.health == 0) {
        // 角色已死亡
        if (deadAnimation.isFinishedOnceUpdate(delta)) {
            menu.menuIndex = 2;
        }
    }
    hurtTimer.update(delta);

    if (velocityTimer.isFinishedLoopUpdate(delta)) {
        // 速度衰减不应该和帧率相关
        velocity = velocity.scale(0.9);
    }

    if (window.isKeyPress(.A)) velocity.x = -maxSpeed;
    if (window.isKeyPress(.D)) velocity.x = maxSpeed;
    if (window.isKeyPress(.W)) velocity.y = -maxSpeed;
    if (window.isKeyPress(.S)) velocity.y = maxSpeed;

    move(delta);
    position.clamp(.zero, worldSize.sub(size));
    animation.loopUpdate(delta);
}

pub fn hurt(damage: u32) void {
    if (hurtTimer.isRunning()) return; // 受伤后的无敌时间

    stats.health -|= damage; // 扣除生命值
    hurtTimer.elapsed = 0; // 重置计时器
    if (stats.health == 0) {
        battle.saveHighScore();
        // 播放死亡音效
        zhu.audio.playSound("assets/sound/female-scream-02-89290.ogg");
    } else {
        // 播放受伤音效
        zhu.audio.playSound("assets/sound/hit-flesh-02-266309.ogg");
    }
}

fn move(delta: f32) void {
    position = position.add(velocity.scale(delta));

    const new: Status = if (velocity.length2() < 0.01) .idle else .move;
    if (new == status) return; // 状态未变化
    status = new;
    animation.image = if (new == .move) moveImage else idleImage;
}

pub fn draw() void {
    if (stats.health == 0) {
        if (!deadAnimation.isRunning()) return; // 动画结束不需要显示

        const image = deadAnimation.currentImage();
        return camera.drawImage(image, position, .{
            .size = size.scale(2), // 和角色的显示区域一样大
            .anchor = .center,
        });
    }

    if (hurtTimer.isRunning() and hurtTimer.isEvenStep(0.2)) return;
    camera.drawImage(animation.currentImage(), position, .{
        .size = size.scale(2),
        .anchor = .center,
        .flipX = velocity.x < 0,
    });
}
