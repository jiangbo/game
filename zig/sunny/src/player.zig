const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const map = @import("map.zig");
const scene = @import("scene.zig");

const moveForce = 200; // 移动力
const factor = 0.85; // 减速因子
const maxSpeed = 120; // 最大速度
const gravity = 980; // 重力
const jumpSpeed = 350.0; // 跳跃速度
const hurtVelocity: zhu.Vector2 = .xy(-100, -150);

const imageSize: zhu.Vector2 = .xy(32, 32);
var viewSize: zhu.Vector2 = undefined;
var tile: tiled.Tile = undefined;
var tiledObject: tiled.Object = undefined;
var image: zhu.graphics.Image = undefined;

var force: zhu.Vector2 = .xy(0, gravity);
pub var velocity: zhu.Vector2 = .zero;
pub var position: zhu.Vector2 = undefined;
pub var state: State = .idle;
var flip: bool = false;

const maxHealth: u8 = 3;
pub var health: u8 = maxHealth;
pub var score: u32 = 0;
var hurtTimer: zhu.Timer = .initFinished(2.0); // 受伤的间隔时间

pub fn init(pos: zhu.Vector2, size: zhu.Vector2) void {
    position = pos;
    viewSize = size;
    const imageId = zhu.assets.id("textures/Actors/foxy.png");
    tile = getTileByImageId(imageId);
    tiledObject = tile.objectGroup.?.objects[0];

    const playerImage = zhu.getImage("textures/Actors/foxy.png").?;
    image = playerImage.sub(.init(.zero, imageSize));
    inline for (std.meta.fields(State)) |field| field.type.init();

    state.enter();
}

fn getTileByImageId(imageId: u32) tiled.Tile {
    for (map.map.tileSets) |tileSet| {
        for (tileSet.tiles) |item| {
            if (item.id == imageId) return item;
        }
    }
    unreachable;
}

pub fn update(delta: f32) void {
    hurtTimer.update(delta);
    state.update(delta);

    velocity = velocity.add(force.scale(delta));
    velocity.x = std.math.clamp(velocity.x, -maxSpeed, maxSpeed);
    var toPosition = position.add(velocity.scale(delta));
    // 角色不移动到屏幕外
    const max = zhu.camera.bound.x - tiledObject.size.x;
    toPosition.x = std.math.clamp(toPosition.x, 0, max);

    if (state == .dead) position = toPosition else {
        const size = tiledObject.size;
        const onTop = map.isTopLadder(toPosition, size);
        if (state != .climb and onTop) {
            velocity.y = 0;
            position = .xy(toPosition.x, position.y);
            const canClimb = map.canClimb(toPosition, size);
            if (zhu.key.held(.S) and canClimb) {
                changeState(.climb);
                position = toPosition;
            }
        } else {
            const clamped = map.clamp(position, toPosition, size);
            if (clamped.x == position.x) velocity.x = 0;
            if (clamped.y == position.y) velocity.y = 0;
            position = clamped;
        }
    }

    if (map.nextLevelArea) |area| { // 角色进入下一关
        if (area.contains(position)) scene.changeNextLevel();
    }

    if (state == .climb) {
        if (toPosition.y > position.y) changeState(.idle);
        velocity = .zero;
    } else force.y = gravity;

    zhu.camera.smoothFollow(position, delta * 4);
    zhu.camera.roundPosition();
}

pub fn collideRect() zhu.Rect {
    return .init(position, tiledObject.size);
}

pub fn hurt() void {
    if (hurtTimer.isRunning()) return; // 受伤间隔时间内，忽略伤害
    health -|= 1;
    hurtTimer.elapsed = 0; // 重置计时器
    if (health == 0) changeState(.dead) else changeState(.hurt);
}

pub fn heal() void {
    if (health < maxHealth) health += 1;
}

pub fn draw() void {
    if (hurtTimer.isRunning()) { // 受伤时闪烁效果
        if (hurtTimer.isEvenStep(0.15)) state.draw();
    } else state.draw();

    zhu.camera.push(.window);
    defer zhu.camera.pop();

    // 绘制得分
    const pos: zhu.Vector2 = .xy(zhu.window.size.x - 100, 10);
    zhu.text.drawFmt("Score: {}", .{score}, pos, .{});

    // 绘制生命值
    const startPos: zhu.Vector2 = .xy(10, 10);
    const healthImage = zhu.getImage("textures/UI/Heart.png").?;
    const backImage = zhu.getImage("textures/UI/Heart-bg.png").?;
    for (0..maxHealth) |index| {
        const img = if (index < health) healthImage else backImage;
        const i: f32 = @floatFromInt(index);
        batch.drawImage(img, startPos.addX(25 * i), .{
            .size = .xy(20, 18), // 图片太大，缩小显示
        });
    }
}

pub fn drawPlayer(img: zhu.graphics.Image) void {
    const pos = position.sub(tiledObject.position);
    batch.drawImage(img, pos, .{
        .uvRect = img.uvFlip(flip, false),
        .size = viewSize,
    });
}

const State = union(enum) {
    idle: IdleState,
    walk: WalkState,
    jump: JumpState,
    fall: FallState,
    hurt: HurtState,
    dead: DeadState,
    climb: ClimbState,

    fn enter(self: State) void {
        switch (self) {
            inline else => |case| @TypeOf(case).enter(),
        }
    }

    fn update(self: State, delta: f32) void {
        switch (self) {
            inline else => |case| @TypeOf(case).update(delta),
        }
    }

    fn draw(self: State) void {
        switch (self) {
            inline else => |case| @TypeOf(case).draw(),
        }
    }
};

fn changeState(newState: State) void {
    state = newState;
    state.enter();
}

const IdleState = struct {
    var animation: zhu.graphics.Animation = undefined;
    const frames = zhu.graphics.loopFramesX(4, imageSize, 0.2);

    pub fn init() void {
        const idleImage = image.sub(.init(.zero, .xy(32, 128)));
        animation = .init(idleImage, imageSize, &frames);
    }

    fn enter() void {
        std.log.info("enter idle", .{});
        force.x = 0;
    }

    fn update(delta: f32) void {
        _ = animation.update(delta);

        if (map.isTouchLadder(position, tiledObject.size) and
            zhu.key.anyHeld(&.{ .W, .DOWN }))
        {
            changeState(.climb);
        }
        if (zhu.key.pressed(.SPACE)) {
            changeState(.jump);
        } else if (zhu.key.anyHeld(&.{ .A, .D, .LEFT, .RIGHT })) {
            changeState(.walk);
        } else velocity.x *= factor; // 减速
    }

    fn draw() void {
        drawPlayer(animation.subImage());
    }
};

const WalkState = struct {
    var animation: zhu.graphics.Animation = undefined;
    const frames = zhu.graphics.loopFramesX(6, imageSize, 0.1);

    pub fn init() void {
        const walkImage = image.sub(.init(.xy(0, 32), .xy(32, 198)));
        animation = .init(walkImage, imageSize, &frames);
    }

    fn enter() void {
        std.log.info("enter walk", .{});
    }

    fn update(delta: f32) void {
        _ = animation.update(delta);
        force.x = 0;

        if (velocity.y > 0) return changeState(.fall);

        if (zhu.key.anyPressed(&.{.SPACE})) {
            changeState(.jump);
        }

        if (zhu.key.anyHeld(&.{ .A, .LEFT })) {
            force.x = -moveForce;
            flip = true;
        } else if (zhu.key.anyHeld(&.{ .D, .RIGHT })) {
            force.x = moveForce;
            flip = false;
        } else {
            changeState(.idle);
        }
    }

    fn draw() void {
        drawPlayer(animation.subImage());
    }
};
const JumpState = struct {
    var jumpImage: zhu.graphics.Image = undefined;

    pub fn init() void {
        jumpImage = image.sub(.init(.xy(0, 160), imageSize));
    }

    fn enter() void {
        std.log.info("enter jump", .{});
        velocity.y = -jumpSpeed;
        zhu.audio.playSound("audio/cartoon-jump-6462.ogg");
    }

    fn update(_: f32) void {
        if (velocity.y > 0) {
            changeState(.fall);
        }
    }

    fn draw() void {
        drawPlayer(jumpImage);
    }
};
const FallState = struct {
    var fallImage: zhu.graphics.Image = undefined;

    pub fn init() void {
        fallImage = image.sub(.init(.xy(32, 160), imageSize));
    }

    fn enter() void {
        std.log.info("enter fall", .{});
    }

    fn update(_: f32) void {
        if (velocity.y == 0) {
            changeState(.idle);
        }
    }

    fn draw() void {
        drawPlayer(fallImage);
    }
};

const HurtState = struct {
    var animation: zhu.graphics.Animation = undefined;
    const frames = zhu.graphics.framesX(2, imageSize, 0.1);
    var timer: zhu.Timer = .init(0.4);

    pub fn init() void {
        const hurtImage = image.sub(.init(.xy(0, 128), .xy(64, 32)));
        animation = .init(hurtImage, imageSize, &frames);
    }

    fn enter() void {
        std.log.info("enter hurt", .{});
        var vel = hurtVelocity;
        if (flip) vel.x = -vel.x;
        velocity = .xy(vel.x, velocity.y + vel.y);
        timer.elapsed = 0; // 重置计时器
        zhu.audio.playSound("audio/monster.ogg");
    }

    fn update(delta: f32) void {
        _ = animation.update(delta);

        if (velocity.y == 0) {
            changeState(.idle);
        } else if (timer.updateFinished(delta)) {
            changeState(.fall);
        }
    }

    fn draw() void {
        drawPlayer(animation.subImage());
    }
};

const DeadState = struct {
    var animation: zhu.graphics.Animation = undefined;
    const frames = zhu.graphics.framesX(2, imageSize, 0.1);

    pub fn init() void {
        const hurtImage = image.sub(.init(.xy(0, 128), .xy(64, 32)));
        animation = .init(hurtImage, imageSize, &frames);
    }

    fn enter() void {
        std.log.info("enter dead", .{});
        velocity = .xy(0, -200);
        zhu.audio.playSound("audio/dead-8bit-41400.ogg");
    }

    fn update(delta: f32) void {
        _ = animation.update(delta);
    }

    fn draw() void {
        drawPlayer(animation.subImage());
    }
};

const ClimbState = struct {
    var animation: zhu.graphics.Animation = undefined;
    const frames = zhu.graphics.loopFramesX(4, imageSize, 0.1);
    const speed = 100;

    pub fn init() void {
        const climbImage = image.sub(.init(.xy(0, 64), .xy(128, 32)));
        animation = .init(climbImage, imageSize, &frames);
    }

    fn enter() void {
        std.log.info("enter climb", .{});
        velocity = .zero;
        force = .zero;
    }

    fn update(delta: f32) void {
        if (zhu.key.held(.W)) {
            velocity.y = -speed;
        } else if (zhu.key.held(.S)) {
            velocity.y = speed;
        } else if (zhu.key.held(.A)) {
            velocity.x = -speed;
        } else if (zhu.key.held(.D)) {
            velocity.x = speed;
        } else velocity = .zero;

        if (velocity.x != 0 or velocity.y != 0) {
            _ = animation.update(delta);
        }

        if (!map.isTouchLadder(position, tiledObject.size)) {
            changeState(.fall);
        }
    }

    fn draw() void {
        drawPlayer(animation.subImage());
    }
};
