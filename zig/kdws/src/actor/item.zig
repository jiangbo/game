const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");
const scene = @import("../scene.zig");
const actor = @import("actor.zig");
const audio = @import("../audio.zig");

pub const Sword = struct {
    const SPEED_MOVE = 1250;

    position: math.Vector,
    moveLeft: bool,
    valid: bool = true,
    animation: gfx.SliceFrameAnimation,
    box: *actor.CollisionBox,

    pub fn init(pos: math.Vector, moveLeft: bool) Sword {
        var self: Sword = .{
            .position = pos,
            .moveLeft = moveLeft,
            .animation = .load("assets/enemy/sword/{}.png", 3),
            .box = scene.addCollisionBox(.{ .rect = .{} }),
        };

        self.animation.anchor = .centerCenter;

        self.box.rect = .{ .w = 150, .h = 10 };
        self.box.setCenter(self.position);
        self.box.dst = .player;
        return self;
    }

    pub fn update(self: *Sword, delta: f32) void {
        self.animation.update(delta);

        const direction: f32 = if (self.moveLeft) -1 else 1;
        self.position.x += direction * SPEED_MOVE * delta;
        self.box.setCenter(self.position);

        if (self.position.x < -200 or self.position.x > window.width + 200) {
            self.valid = false;
            self.box.active = false;
        }
    }

    pub fn render(self: *const Sword) void {
        gfx.playSliceFlipX(&self.animation, self.position, !self.moveLeft);
    }
};

pub const Barb = struct {
    const SPEED_DASH = 1500;

    const State = enum { idle, aim, dash, death };

    basePosition: math.Vector,
    position: math.Vector,
    velocity: math.Vector = .zero,
    active: bool = true,

    idleTimer: window.Timer = undefined,
    aimTimer: window.Timer = .init(0.75),
    totalTime: f32 = 0,
    diffPeriod: f32 = 0,

    looseAnimation: gfx.SliceFrameAnimation,
    deathAnimation: gfx.SliceFrameAnimation,
    state: State = .idle,
    box: *actor.CollisionBox,

    pub fn init(pos: math.Vector) Barb {
        var self: Barb = .{
            .basePosition = pos,
            .position = pos,
            .diffPeriod = window.randomFloat(0, 6),
            .looseAnimation = .load("assets/enemy/barb_loose/{}.png", 5),
            .deathAnimation = .load("assets/enemy/barb_break/{}.png", 3),
            .box = scene.addCollisionBox(.{ .rect = .{ .w = 20, .h = 20 } }),
        };

        self.looseAnimation.timer.duration = 0.15;
        self.looseAnimation.anchor = .centerCenter;

        self.deathAnimation.loop = false;
        self.deathAnimation.anchor = .centerCenter;

        self.idleTimer = .init(window.randomFloat(3, 10));

        self.box.src = .enemy;
        self.box.dst = .player;
        self.box.setCenter(self.position);

        return self;
    }

    pub fn update(self: *Barb, delta: f32) void {
        self.looseAnimation.update(delta);
        self.totalTime += delta;

        self.box.setCenter(self.position);
        if (self.box.active and self.box.collided) self.collided();

        switch (self.state) {
            .idle => {
                const offsetY = 30 * @sin(self.totalTime * 2 + self.diffPeriod);
                self.position.y = self.basePosition.y + offsetY;
                if (self.idleTimer.isFinishedAfterUpdate(delta)) {
                    self.state = .aim;
                }
            },
            .aim => {
                const offsetX = window.randomFloat(-10, 10);
                self.position.x = self.basePosition.x + offsetX;
                if (self.aimTimer.isFinishedAfterUpdate(delta)) {
                    self.state = .dash;
                    const direction = scene.player.shared.position.sub(self.position);
                    self.velocity = direction.normalize().scale(SPEED_DASH);
                }
            },
            .dash => {
                self.position = self.position.add(self.velocity.scale(delta));
                if (self.position.y > actor.SharedActor.FLOOR_Y) {
                    self.velocity = .zero;
                    self.position.y = actor.SharedActor.FLOOR_Y;
                    self.collided();
                } else if (self.position.y < 0) self.collided();
            },
            .death => {
                self.deathAnimation.update(delta);
                if (self.deathAnimation.finished()) {
                    self.active = false;
                }
            },
        }
    }

    pub fn collided(self: *Barb) void {
        self.state = .death;
        self.box.active = false;
        audio.playSound("assets/audio/barb_break.ogg");
    }

    pub fn render(self: *const Barb) void {
        if (self.state == .death) {
            gfx.playSlice(&self.deathAnimation, self.position);
        } else {
            gfx.playSlice(&self.looseAnimation, self.position);
        }
    }
};
