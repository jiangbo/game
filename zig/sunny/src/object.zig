const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const map = @import("map.zig");
const getImage = zhu.assets.getImage;
const player = @import("player.zig");

const gemFrames = zhu.graphics.framesX(5, .xy(15, 13), 0.2);
const cherryFrames = zhu.graphics.loopFramesX(5, .xy(21, 21), 0.2);
const opossumFrames = zhu.graphics.framesX(6, .xy(36, 28), 0.1);
const eagleFrames = zhu.graphics.framesX(4, .xy(40, 41), 0.15);
const itemFrames = zhu.graphics.framesX(5, .xy(32, 32), 0.1);
const deadFrames = zhu.graphics.framesX(6, .xy(40, 41), 0.1);

var gemAnimation: zhu.graphics.Animation = undefined;
var cherryAnimation: zhu.graphics.Animation = undefined;
var opossumAnimation: zhu.graphics.Animation = undefined;
var eagleAnimation: zhu.graphics.Animation = undefined;
var itemAnimation: zhu.graphics.Animation = undefined;
var deadAnimation: zhu.graphics.Animation = undefined;

var skullImage: zhu.graphics.Image = undefined;
var spikeImage: zhu.graphics.Image = undefined;

const frogEnum = enum { idle, jump, fall };
const frogIdleFrames = zhu.graphics.framesX(4, .xy(35, 32), 0.3);
const frogJumpFrames: [1]zhu.graphics.Frame = .{
    .{ .offset = .xy(35, 32) },
};
const frogFallFrames: [1]zhu.graphics.Frame = .{
    .{ .offset = .xy(70, 32) },
};
var frogAnimations: zhu.graphics.EnumAnimation(frogEnum) = undefined;
var frogState: frogEnum = .idle;

const Animation = struct {
    center: zhu.Vector2, // 需要播放的中心点
    effect: zhu.graphics.Animation,
};

var effectArray: [10]Animation = undefined;
var effectAnimations: std.ArrayList(Animation) = undefined;
var objects: std.ArrayList(map.Object) = undefined;

pub fn init(obj: std.ArrayList(map.Object)) void {
    objects = obj;

    const gemImage = getImage(@intFromEnum(map.ObjectEnum.gem)).?;
    gemAnimation = .init(gemImage, .xy(15, 13), &gemFrames);

    const cherryImage = getImage(@intFromEnum(map.ObjectEnum.cherry)).?;
    cherryAnimation = .init(cherryImage, .xy(21, 21), &cherryFrames);

    const opossumImage = getImage(@intFromEnum(map.ObjectEnum.opossum)).?;
    opossumAnimation = .init(opossumImage, .xy(36, 28), &opossumFrames);

    const eagleImage = getImage(@intFromEnum(map.ObjectEnum.eagle)).?;
    eagleAnimation = .init(eagleImage, .xy(40, 41), &eagleFrames);

    const frogImage = getImage(@intFromEnum(map.ObjectEnum.frog)).?;
    frogAnimations.set(.idle, .init(frogImage, .xy(35, 32), &frogIdleFrames));
    frogAnimations.set(.jump, .init(frogImage, .xy(35, 32), &frogJumpFrames));
    frogAnimations.set(.fall, .init(frogImage, .xy(35, 32), &frogFallFrames));

    const itemImage = zhu.getImage("textures/FX/item-feedback.png").?;
    itemAnimation = .init(itemImage, .xy(32, 32), &itemFrames);
    itemAnimation.loop = false;
    const deadImage = zhu.getImage("textures/FX/enemy-deadth.png").?;
    deadAnimation = .init(deadImage, .xy(40, 41), &deadFrames);
    deadAnimation.loop = false;
    effectAnimations = .initBuffer(&effectArray);

    skullImage = getImage(@intFromEnum(map.ObjectEnum.skull)).?;
    spikeImage = getImage(@intFromEnum(map.ObjectEnum.spikeTop)).?;

    for (objects.items) |*object| {
        switch (object.type) {
            .opossum => object.velocity = .xy(-80, 0),
            .eagle => object.velocity = .xy(0, -60),
            else => {},
        }
    }
}

pub fn update(delta: f32) void {
    _ = gemAnimation.update(delta);
    _ = cherryAnimation.update(delta);
    _ = opossumAnimation.update(delta);
    _ = eagleAnimation.update(delta);
    _ = frogAnimations.getPtr(frogState).update(delta);

    { // 特效动画
        var iterator = std.mem.reverseIterator(effectAnimations.items);
        while (iterator.nextPtr()) |animation| {
            if (animation.effect.update(delta) == .end) {
                _ = effectAnimations.swapRemove(iterator.index);
            }
        }
    }

    // AI 行为
    for (objects.items) |*object| {
        switch (object.type) {
            .opossum => updateOpossum(object, delta),
            .eagle => updateEagle(object, delta),
            .frog => updateFrog(object, delta),
            else => {},
        }
    }

    if (player.state == .dead) return;

    const playerRect = player.collideRect();
    var iterator = std.mem.reverseIterator(objects.items);
    while (iterator.nextPtr()) |item| {
        // 检测碰撞框
        if (item.object == null) continue;
        const obj = item.object.?;
        const pos = item.position.add(obj.position);
        const rect = zhu.Rect.init(pos, obj.size); // 碰撞区域
        if (playerRect.intersect(rect)) {
            // 玩家与物体发生碰撞，根据不同对象，不同处理。
            switch (item.type) {
                .gem, .cherry => {
                    collideItem(item, rect.center());
                    _ = objects.swapRemove(iterator.index);
                },
                .opossum, .eagle, .frog => {
                    const area = playerRect.overlapArea(rect);
                    if (playerRect.center().y < area.center().y and
                        area.size.x > area.size.y)
                    {
                        // 从上方碰撞，击败敌人
                        collideEnemy(item, rect.center());
                        _ = objects.swapRemove(iterator.index);
                        player.score += 10;
                        zhu.audio.playSound("audio/punch2a.ogg");
                    } else player.hurt();
                },
                .spike, .spikeTop => player.hurt(),
                else => unreachable,
            }
        }
    }
}

fn updateOpossum(object: *map.Object, delta: f32) void {
    const offset = object.velocity.scale(delta);
    object.position = object.position.add(offset);
    const max = object.initPosition.x;
    if (object.position.x < max - 200 or object.position.x > max) {
        object.velocity.x = -object.velocity.x;
    }
}

fn updateEagle(object: *map.Object, delta: f32) void {
    const offset = object.velocity.scale(delta);
    object.position = object.position.add(offset);
    const max = object.initPosition.y;
    if (object.position.y > max or object.position.y < max - 80) {
        object.velocity.y = -object.velocity.y;
    }
}

const gravity = 980; // 重力
var jumpTimer: zhu.Timer = .init(2.5);
var jumpRight: bool = true;
fn updateFrog(object: *map.Object, delta: f32) void {
    if (jumpTimer.updateLooped(delta)) {
        const max = object.initPosition.x - 10;
        if (object.position.x > max) jumpRight = false;
        if (object.position.x < max - 90) jumpRight = true;

        const x: f32 = if (jumpRight) 1 else -1;
        object.velocity = .xy(50 * x, -350);
    }

    const pos = object.position.add(object.object.?.position);
    object.velocity.y = object.velocity.y + gravity * delta;
    const toPosition = pos.add(object.velocity.scale(delta));

    const size = object.object.?.size;
    const clamped = map.clamp(pos, toPosition, size);
    if (clamped.y == pos.y) object.velocity = .zero;

    object.position = clamped.sub(object.object.?.position);

    const oldState = frogState;
    frogState = if (object.velocity.y == 0) .idle //
        else if (object.velocity.y < 0) .jump else .fall;
    if (oldState == .fall and frogState == .idle) { // 刚刚落地
        // 距离足够近才播放声音
        const length2 = clamped.sub(player.position).length2();
        if (length2 < 200 * 200) {
            zhu.audio.playSound("audio/frog_quak-81741.ogg");
        }
    }
}

fn collideItem(object: *map.Object, center: zhu.Vector2) void {
    // 播放特效动画
    effectAnimations.appendAssumeCapacity(.{
        .center = center,
        .effect = itemAnimation,
    });

    if (object.type == .gem) player.score += 5 //
    else if (object.type == .cherry) player.heal();

    zhu.audio.playSound("audio/poka01.ogg");
}

fn collideEnemy(_: *map.Object, center: zhu.Vector2) void {
    // 播放特效动画
    effectAnimations.appendAssumeCapacity(.{
        .center = center,
        .effect = deadAnimation,
    });
    player.velocity.y = -300; // 弹起
}

pub fn draw() void {
    for (objects.items) |item| {
        const image: ?zhu.graphics.Image = switch (item.type) {
            .gem => gemAnimation.subImage(),
            .cherry => cherryAnimation.subImage(),
            .opossum => opossumAnimation.subImage(),
            .eagle => eagleAnimation.subImage(),
            .frog => frogAnimations.get(frogState).subImage(),
            .skull => skullImage,
            .spikeTop => spikeImage,
            else => null,
        };

        if (image) |img| {
            var flip = item.velocity.x > 0;
            if (item.type == .frog) flip = jumpRight;
            batch.drawImage(img, item.position, .{
                .uvRect = img.uvFlip(flip, false),
            });
        }
    }

    // 绘制特效动画
    for (effectAnimations.items) |animation| {
        const img = animation.effect.subImage();
        batch.drawImage(img, animation.center, .{ .anchor = .center });
    }
}
