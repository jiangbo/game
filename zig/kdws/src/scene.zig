const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const actor = @import("actor/actor.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

pub const BulletTimerState = enum { entering, exiting };

const SPEED_PROGRESS = 2;
const DST_DELTA_FACTOR = 0.35;

var debug: bool = false;
var pause: bool = false;
pub var player: actor.Player = undefined;
pub var enemy: actor.Enemy = undefined;
pub var boxes: std.BoundedArray(actor.CollisionBox, 30) = undefined;

pub var bulletTime: bool = false;
pub var progress: f32 = 0;
pub var postProcessTexture: gfx.Texture = undefined;

pub fn init() void {
    boxes = std.BoundedArray(actor.CollisionBox, 30).init(0) catch unreachable;
    player = actor.Player.init();
    enemy = actor.Enemy.init();

    const data = [_]u8{ 0x00, 0x00, 0x00, 0x99 };
    postProcessTexture = gfx.Texture.init(1, 1, &data);

    audio.playMusic("assets/audio/bgm.ogg");
}

pub fn addCollisionBox(box: actor.CollisionBox) *actor.CollisionBox {
    for (boxes.slice()) |*value| {
        if (value.active) continue;
        value.* = box;
        return value;
    } else {
        boxes.appendAssumeCapacity(box);
        return &boxes.slice()[boxes.len - 1];
    }
}

pub fn deinit() void {
    audio.stopMusic();
}

pub fn event(ev: *const window.Event) void {
    if (ev.type == .KEY_UP and ev.key_code == .X) {
        debug = !debug;
        return;
    }

    if (ev.type == .KEY_UP and ev.key_code == .Z) {
        pause = !pause;
        return;
    }

    player.event(ev);
}

pub fn update() void {
    if (pause) return;

    const realDelta = window.deltaSecond();

    const dir: f32 = if (bulletTime) 1.0 else -1.0;
    progress += SPEED_PROGRESS * realDelta * dir;
    progress = std.math.clamp(progress, 0, 1);
    const delta = std.math.lerp(1, DST_DELTA_FACTOR, progress) * realDelta;

    player.update(delta);
    enemy.update(delta);

    for (boxes.slice()) |*srcBox| {
        if (!srcBox.enable or srcBox.dst == .none or !srcBox.active) continue;
        for (boxes.slice()) |*dstBox| {
            if (!dstBox.enable or srcBox == dstBox or //
                srcBox.dst != dstBox.src or !dstBox.active) continue;

            if (srcBox.rect.intersects(dstBox.rect)) {
                dstBox.collided = true;
                if (dstBox.callback) |callback| callback();
            }
        }
    }
}
pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    renderBackground();
    enemy.render();

    if (progress > 0.5) {
        gfx.drawOptions(postProcessTexture, .{
            .targetRect = .{ .w = window.width, .h = window.height },
        });
    }

    player.render();

    if (debug) {
        for (boxes.slice()) |box| {
            if (box.enable and box.active) gfx.drawRectangle(box.rect);
        }
    }
}

pub fn renderBackground() void {
    const background = gfx.loadTexture("assets/background.png");
    const width = window.width - background.width();
    const height = window.height - background.height();
    gfx.draw(background, width / 2, height / 2);
}
