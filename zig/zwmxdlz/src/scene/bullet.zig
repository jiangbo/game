const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const audio = @import("zaudio");

const scene = @import("../scene.zig");

var peaBreakSound: [3]*audio.Sound = undefined;
var peaShootSound: [2]*audio.Sound = undefined;
var peaShootExSound: *audio.Sound = undefined;

var sunExplodeSound: *audio.Sound = undefined;
var sunExplodeExSound: *audio.Sound = undefined;
var sunTextSound: *audio.Sound = undefined;

pub fn init() void {
    peaBreakSound[0] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_break_1.mp3", .{}) catch unreachable;
    peaBreakSound[1] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_break_2.mp3", .{}) catch unreachable;
    peaBreakSound[2] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_break_3.mp3", .{}) catch unreachable;

    peaShootSound[0] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_shoot_1.mp3", .{}) catch unreachable;

    peaShootSound[1] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_shoot_2.mp3", .{}) catch unreachable;

    peaShootExSound = scene.audioEngine.createSoundFromFile( //
        "assets/pea_shoot_ex.mp3", .{}) catch unreachable;

    sunExplodeSound = scene.audioEngine.createSoundFromFile( //
        "assets/sun_explode.mp3", .{}) catch unreachable;

    sunExplodeExSound = scene.audioEngine.createSoundFromFile( //
        "assets/sun_explode_ex.mp3", .{}) catch unreachable;

    sunTextSound = scene.audioEngine.createSoundFromFile( //
        "assets/sun_text.mp3", .{}) catch unreachable;
}

pub fn deinit() void {
    for (peaBreakSound) |sound| sound.destroy();
    for (peaShootSound) |sound| sound.destroy();
    peaShootExSound.destroy();
    sunExplodeSound.destroy();
    sunExplodeExSound.destroy();
    sunTextSound.destroy();
}

pub const Vector = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn add(a: Vector, b: Vector) Vector {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn scale(a: Vector, b: f32) Vector {
        return .{ .x = a.x * b, .y = a.y * b, .z = a.z * b };
    }

    pub fn sub(a: Vector, b: Vector) Vector {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }
};

pub const Bullet = struct {
    size: Vector,
    position: Vector,
    velocity: Vector,
    damage: u32,
    dead: bool = false,
    collide: bool = false,
    p1: bool = true,
    explodeOffset: Vector = .{},

    type: Type = .pea,
    animationIdle: gfx.FrameAnimation,
    animationBreak: gfx.FrameAnimation,

    texture: gfx.Texture = undefined,

    const peaSpeed: f32 = 0.75;
    const peaSpeedEx: f32 = 1.5;
    const gravity: f32 = 1.6e-3;
    const Type = enum { pea, sun, sunEx };

    pub fn init(p1: bool) Bullet {
        const playerType = if (p1) scene.playerType1 else scene.playerType2;
        var self = switch (playerType) {
            .peaShooter => initPeaBullet(),
            .sunFlower => initSunBullet(),
        };

        self.size = .{ .x = self.texture.width, .y = self.texture.height };
        self.p1 = p1;
        return self;
    }

    fn initPeaBullet() Bullet {
        var self: Bullet = undefined;
        self.texture = gfx.loadTexture("assets/pea.png").?;
        self.type = .pea;
        self.animationBreak = .load("assets/pea_break_{}.png", 3);
        self.animationBreak.loop = false;
        self.damage = 5;
        self.velocity = .{ .x = peaSpeed };

        return self;
    }

    fn initSunBullet() Bullet {
        var self: Bullet = undefined;
        self.texture = gfx.loadTexture("assets/sun_1.png").?;
        self.type = .sun;
        self.animationIdle = .load("assets/sun_{}.png", 5);
        self.animationBreak = .load("assets/sun_explode_{}.png", 5);
        self.animationBreak.timer.duration = 75;
        self.animationBreak.loop = false;
        self.damage = 10;
        self.velocity = .{ .x = 0.25, .y = -0.65 };

        self.explodeOffset = .{
            .x = (self.texture.width - self.animationBreak.textures[0].width) / 2,
            .y = (self.texture.height - self.animationBreak.textures[0].height) / 2,
        };

        return self;
    }

    pub fn initSunBulletEx() Bullet {
        var self: Bullet = undefined;
        self.texture = gfx.loadTexture("assets/sun_ex_1.png").?;
        self.type = .sunEx;
        self.animationIdle = .load("assets/sun_ex_{}.png", 5);
        self.animationBreak = .load("assets/sun_ex_explode_{}.png", 5);
        self.animationBreak.timer.duration = 75;
        self.animationBreak.loop = false;
        self.damage = 20;
        self.velocity = .{ .y = 0.15 };
        self.position.y = -self.texture.height;

        self.explodeOffset = .{
            .x = (self.texture.width - self.animationBreak.textures[0].width) / 2,
            .y = (self.texture.height - self.animationBreak.textures[0].height) / 2,
        };

        self.size = .{ .x = self.texture.width, .y = self.texture.height };

        return self;
    }

    pub fn playShootSound(self: *Bullet) void {
        if (self.type == .pea) {
            const i = window.rand.uintLessThanBiased(u32, peaShootSound.len);
            peaShootSound[i].start() catch unreachable;
        }
    }

    pub fn playShootExSound(playerType: scene.PlayerType) void {
        if (playerType == .peaShooter)
            peaShootExSound.start() catch unreachable
        else
            sunTextSound.start() catch unreachable;
    }

    pub fn center(self: Bullet) Vector {
        return .{
            .x = self.position.x + self.size.x / 2,
            .y = self.position.y + self.size.y / 2,
        };
    }

    pub fn update(self: *Bullet, delta: f32) void {
        if (self.type == .sun) {
            self.velocity = self.velocity.add(.{ .y = gravity * delta });
        }
        const position = self.position.add(self.velocity.scale(delta));

        if (self.collide) {
            self.animationBreak.update(delta);
            if (self.type == .pea) self.position = position;
            if (self.animationBreak.finished()) self.dead = true;
            return;
        }

        if (outWindow(position, self.size)) self.dead = true;

        if (self.type != .pea) self.animationIdle.update(delta);
        self.position = position;
    }

    pub fn collidePlayer(self: *Bullet) void {
        self.collide = true;

        switch (self.type) {
            .pea => {
                const i = window.rand.uintLessThanBiased(u32, peaBreakSound.len);
                peaBreakSound[i].start() catch unreachable;
            },
            .sun => {
                sunExplodeSound.start() catch unreachable;
                window.shakeCamera.restart(5, 250);
            },
            .sunEx => {
                sunExplodeExSound.start() catch unreachable;
                window.shakeCamera.restart(20, 350);
            },
        }
    }

    fn outWindow(position: Vector, size: Vector) bool {
        if (position.x + size.x < 0 or position.x > window.width) return true;
        if (position.y + size.y < 0 or position.y > window.height) return true;
        return false;
    }

    pub fn render(self: *Bullet) void {
        if (self.collide) {
            const pos = self.position.add(self.explodeOffset);
            self.animationBreak.play(pos.x, pos.y);
        } else switch (self.type) {
            .pea => gfx.draw(self.position.x, self.position.y, self.texture),
            .sun => self.animationIdle.play(self.position.x, self.position.y),
            .sunEx => self.animationIdle.play(self.position.x, self.position.y),
        }
    }
};
