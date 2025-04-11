const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");
const scene = @import("../scene.zig");

pub const CollisionLayer = enum { none, player, enemy };

pub const CollisionBox = struct {
    rect: math.Rectangle,
    enable: bool = true,
    src: CollisionLayer = .none,
    dst: CollisionLayer = .none,
    callback: ?*const fn () void = null,
    active: bool = true,
    collided: bool = false,

    pub fn setCenter(self: *CollisionBox, center: math.Vector) void {
        self.rect.x = center.x - self.rect.w / 2;
        self.rect.y = center.y - self.rect.h / 2;
    }
};

pub const Player = @import("Player.zig");
pub const Enemy = @import("Enemy.zig");

pub const SharedActor = struct {
    pub const FLOOR_Y = 620;
    const GRAVITY = 980 * 2;

    enableGravity: bool = true,
    position: math.Vector,
    velocity: math.Vector = .{},
    faceLeft: bool = false,
    logicHeight: f32 = 150,
    health: u8 = 10,

    hitBox: *CollisionBox,
    hurtBox: *CollisionBox,

    isInvulnerable: bool = false,
    invulnerableStatusTimer: window.Timer = .init(1),
    invulnerableBlinkTimer: window.Timer = .init(0.075),
    isBlink: bool = false,

    pub fn init(x: f32) SharedActor {
        return .{
            .position = .{ .x = x, .y = 200 },
            .hitBox = scene.addCollisionBox(.{ .rect = .{} }),
            .hurtBox = scene.addCollisionBox(.{ .rect = .{} }),
        };
    }

    pub fn update(self: *SharedActor, delta: f32) void {
        if (self.health <= 0) self.velocity.x = 0;

        if (self.enableGravity) {
            self.velocity.y += GRAVITY * delta;
        }

        self.position = self.position.add(self.velocity.scale(delta));
        if (self.position.y >= FLOOR_Y) {
            self.position.y = FLOOR_Y;
            self.velocity.y = 0;
        }

        if (self.isInvulnerable) {
            if (self.invulnerableStatusTimer.isFinishedAfterUpdate(delta)) {
                self.isInvulnerable = false;
                self.hurtBox.enable = true;
            }

            if (self.invulnerableBlinkTimer.isFinishedAfterUpdate(delta)) {
                self.isBlink = !self.isBlink;
                self.invulnerableBlinkTimer.reset();
            }
        }

        self.position.x = std.math.clamp(self.position.x, 0, window.width);
        self.hurtBox.setCenter(self.logicCenter());
    }

    pub fn isOnFloor(self: *const SharedActor) bool {
        return self.position.y >= FLOOR_Y;
    }

    pub fn logicCenter(self: *const SharedActor) math.Vector {
        return .{
            .x = self.position.x,
            .y = self.position.y - self.logicHeight / 2,
        };
    }

    pub fn hurtIf(self: *SharedActor) bool {
        if (self.isInvulnerable) return false;

        self.health -|= 1;
        self.enterInvulnerable();
        return true;
    }

    pub fn enterInvulnerable(self: *SharedActor) void {
        self.isInvulnerable = true;
        self.hurtBox.enable = false;
        self.invulnerableStatusTimer.reset();
    }
};
