const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");
const scene = @import("../scene.zig");
const audio = @import("../audio.zig");
const actor = @import("actor.zig");
const item = @import("item.zig");

const Sword = item.Sword;
const Barb = item.Barb;
const Enemy = @This();

shared: actor.SharedActor,
state: State = .idle,

idleTimer: window.Timer = .init(0.5),
idleAnimation: gfx.SliceFrameAnimation,

jumpAnimation: gfx.SliceFrameAnimation,

fallAnimation: gfx.SliceFrameAnimation,

aimTimer: window.Timer = .init(0.5),
aimAnimation: gfx.SliceFrameAnimation,

dashInAirAnimation: gfx.SliceFrameAnimation,
dashInAirVfx: gfx.SliceFrameAnimation,

runAnimation: gfx.SliceFrameAnimation,

squatTimer: window.Timer = .init(0.5),
squatAnimation: gfx.SliceFrameAnimation,

dashTimer: window.Timer = .init(0.5),
dashOnFloorAnimation: gfx.SliceFrameAnimation,
dashOnFloorVfx: gfx.SliceFrameAnimation,

throwSilkTimer: window.Timer = .init(0.9),
throwSilkAnimation: gfx.SliceFrameAnimation,
silkAnimation: gfx.SliceFrameAnimation,
silkBox: *actor.CollisionBox,

swords: std.BoundedArray(Sword, 4),
throwSwordTimer: window.Timer = .init(1),
appearSwordTimer: ?window.Timer = null,
throwSwordAnimation: gfx.SliceFrameAnimation,

barbs: std.BoundedArray(Barb, 18),
throwBarbTimer: window.Timer = .init(0.8),
throwBarbAnimation: gfx.SliceFrameAnimation,

pub fn init() Enemy {
    timer = std.time.Timer.start() catch unreachable;

    var shared: actor.SharedActor = .init(1050);
    shared.faceLeft = true;
    shared.health = 50;

    shared.hitBox.rect = .{ .w = 50, .h = 80 };
    shared.hitBox.dst = .player;

    shared.hurtBox.rect = .{ .w = 100, .h = 180 };
    shared.hurtBox.src = .enemy;
    shared.hurtBox.callback = struct {
        fn callback() void {
            if (scene.enemy.shared.hurtIf()) {
                const rand = window.rand.intRangeAtMostBiased(u8, 1, 3);
                const sound = switch (rand) {
                    1 => "assets/audio/enemy_hurt_1.ogg",
                    2 => "assets/audio/enemy_hurt_2.ogg",
                    3 => "assets/audio/enemy_hurt_3.ogg",
                    else => unreachable,
                };
                audio.playSound(sound);
            }
        }
    }.callback;

    var enemy: Enemy = .{
        .shared = shared,

        .swords = std.BoundedArray(Sword, 4).init(0) catch unreachable,
        .barbs = std.BoundedArray(Barb, 18).init(0) catch unreachable,
        .idleAnimation = .load("assets/enemy/idle/{}.png", 5),
        .jumpAnimation = .load("assets/enemy/jump/{}.png", 8),
        .fallAnimation = .load("assets/enemy/fall/{}.png", 4),
        .aimAnimation = .load("assets/enemy/aim/{}.png", 9),
        .dashInAirAnimation = .load("assets/enemy/dash_in_air/{}.png", 2),
        .dashInAirVfx = .load("assets/enemy/vfx_dash_in_air/{}.png", 5),
        .runAnimation = .load("assets/enemy/run/{}.png", 8),
        .squatAnimation = .load("assets/enemy/squat/{}.png", 10),
        .dashOnFloorAnimation = .load("assets/enemy/dash_on_floor/{}.png", 2),
        .dashOnFloorVfx = .load("assets/enemy/vfx_dash_on_floor/{}.png", 5),
        .throwSilkAnimation = .load("assets/enemy/throw_silk/{}.png", 17),
        .silkAnimation = .load("assets/enemy/silk/{}.png", 9),
        .silkBox = scene.addCollisionBox(.{ .rect = .{ .w = 225, .h = 255 } }),
        .throwSwordAnimation = .load("assets/enemy/throw_sword/{}.png", 16),
        .throwBarbAnimation = .load("assets/enemy/throw_barb/{}.png", 8),
    };

    enemy.silkBox.dst = .player;
    enemy.silkBox.enable = false;

    enemy.aimAnimation.loop = false;
    enemy.aimAnimation.timer = .init(0.05);

    enemy.dashInAirAnimation.timer = .init(0.05);
    enemy.dashOnFloorAnimation.timer = .init(0.05);
    enemy.runAnimation.timer = .init(0.05);
    enemy.jumpAnimation.loop = false;

    enemy.squatAnimation.loop = false;
    enemy.squatAnimation.timer = .init(0.05);
    enemy.throwBarbAnimation.loop = false;
    enemy.throwSilkAnimation.loop = false;
    enemy.throwSwordAnimation.loop = false;
    enemy.throwSwordAnimation.timer = .init(0.05);

    enemy.silkAnimation.anchor = .centerCenter;
    enemy.dashInAirVfx.anchor = .centerCenter;
    enemy.dashInAirVfx.loop = false;
    enemy.dashOnFloorVfx.anchor = .centerCenter;
    enemy.dashOnFloorVfx.loop = false;

    enemy.state.enter(&enemy);
    return enemy;
}

var timer: std.time.Timer = undefined;

pub fn update(self: *Enemy, delta: f32) void {
    self.shared.update(delta);
    self.shared.hitBox.setCenter(self.shared.logicCenter());

    self.state.update(self, delta);
    {
        var i = self.swords.len;
        while (i > 0) : (i -= 1) {
            var sword = &self.swords.slice()[i - 1];
            if (!sword.valid) {
                _ = self.swords.swapRemove(i - 1);
                continue;
            }
            sword.update(delta);
        }
    }
    {
        var i = self.barbs.len;
        while (i > 0) : (i -= 1) {
            var barb = &self.barbs.slice()[i - 1];
            if (barb.active) {
                barb.update(delta);
            } else {
                _ = self.barbs.swapRemove(i - 1);
            }
        }
    }
}

pub fn render(self: *const Enemy) void {
    for (self.swords.slice()) |sword| {
        sword.render();
    }

    for (self.barbs.slice()) |barb| {
        barb.render();
    }

    if (self.shared.isInvulnerable) {
        if (self.shared.isBlink) self.state.render(self);
    } else {
        self.state.render(self);
    }
}

fn changeState(self: *Enemy, new: State) void {
    self.state.exit(self);
    new.enter(self);
}

fn play(self: *const Enemy, animation: *const gfx.SliceFrameAnimation) void {
    gfx.playSliceFlipX(animation, self.shared.position, !self.shared.faceLeft);
}

fn isEnraged(self: *const Enemy) bool {
    return self.shared.health <= 25;
}

const State = union(enum) {
    idle: IdleState,
    jump: JumpState,
    fall: FallState,
    aim: AimState,
    dashInAir: DashInAirState,
    run: RunState,
    squat: SquatState,
    dashOnFloor: DashOnFloorState,
    throwSilk: ThrowSilkState,
    throwSword: ThrowSwordState,
    throwBarb: ThrowBarbState,

    fn enter(self: State, enemy: *Enemy) void {
        switch (self) {
            inline else => |case| @TypeOf(case).enter(enemy),
        }
    }

    fn update(self: State, enemy: *Enemy, delta: f32) void {
        if (enemy.shared.health == 0) {
            std.log.info("win", .{});
            window.exit();
        }

        switch (self) {
            inline else => |case| @TypeOf(case).update(enemy, delta),
        }
    }

    fn render(self: State, enemy: *const Enemy) void {
        switch (self) {
            inline else => |case| @TypeOf(case).render(enemy),
        }
    }

    fn exit(self: State, enemy: *Enemy) void {
        switch (self) {
            inline else => |case| @TypeOf(case).exit(enemy),
        }
    }
};

const IdleState = struct {
    fn enter(enemy: *Enemy) void {
        enemy.state = .idle;
        enemy.shared.velocity.x = 0;

        const max: f32 = if (enemy.isEnraged()) 0.25 else 0.5;
        enemy.idleTimer.duration = window.randomFloat(0, max);
        enemy.idleTimer.reset();
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.idleAnimation.update(delta);
        if (enemy.idleTimer.isRunningAfterUpdate(delta)) return;

        if (!enemy.shared.isOnFloor()) return enemy.changeState(.fall);

        if (enemy.isEnraged()) return updateEnraged(enemy);

        const rand = window.rand.intRangeLessThanBiased(u8, 0, 100);
        const state: State = switch (rand) {
            0...24 => .jump,
            25...49 => .run,
            50...79 => .squat,
            80...89 => .throwSilk,
            else => .throwSword,
        };
        enemy.changeState(state);
    }

    fn updateEnraged(enemy: *Enemy) void {
        const rand = window.rand.intRangeLessThanBiased(u8, 0, 100);
        const state: State = switch (rand) {
            0...24 => .jump,
            25...59 => .throwSword,
            60...69 => .throwSilk,
            70...89 => .throwBarb,
            else => .squat,
        };
        enemy.changeState(state);
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.idleAnimation);
    }

    fn exit(enemy: *Enemy) void {
        enemy.idleAnimation.reset();
        const playerPosition = scene.player.shared.position;
        enemy.shared.faceLeft = playerPosition.x < enemy.shared.position.x;
    }
};

const JumpState = struct {
    const SPEED_JUMP = 1000;

    fn enter(enemy: *Enemy) void {
        enemy.state = .jump;
        enemy.shared.velocity.y = -SPEED_JUMP;
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.jumpAnimation.update(delta);
        if (enemy.shared.velocity.y < 0) return;

        const rand = window.rand.intRangeLessThanBiased(u8, 0, 100);
        if (enemy.isEnraged()) {
            switch (rand) {
                0...49 => enemy.changeState(.throwSilk),
                50...79 => enemy.changeState(.fall),
                else => enemy.changeState(.aim),
            }
        } else {
            switch (rand) {
                0...49 => enemy.changeState(.aim),
                50...79 => enemy.changeState(.fall),
                else => enemy.changeState(.throwSilk),
            }
        }
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.jumpAnimation);
    }

    fn exit(enemy: *Enemy) void {
        enemy.jumpAnimation.reset();
    }
};

const FallState = struct {
    fn enter(enemy: *Enemy) void {
        enemy.state = .fall;
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.fallAnimation.update(delta);
        if (enemy.shared.isOnFloor()) enemy.changeState(.idle);
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.fallAnimation);
    }

    fn exit(enemy: *Enemy) void {
        enemy.fallAnimation.reset();
    }
};

const AimState = struct {
    fn enter(enemy: *Enemy) void {
        enemy.state = .aim;
        enemy.shared.velocity = .zero;
        enemy.shared.enableGravity = false;
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.aimAnimation.update(delta);
        if (enemy.aimTimer.isRunningAfterUpdate(delta)) return;

        enemy.changeState(.dashInAir);
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.aimAnimation);
    }

    fn exit(enemy: *Enemy) void {
        enemy.aimTimer.reset();
        enemy.shared.enableGravity = true;
        enemy.aimAnimation.reset();
    }
};

const DashInAirState = struct {
    const SPEED_DASH = 1500;

    fn enter(enemy: *Enemy) void {
        enemy.state = .dashInAir;
        enemy.shared.enableGravity = false;

        const playerPosition = scene.player.shared.position;
        const target: math.Vector = .{
            .x = playerPosition.x,
            .y = actor.SharedActor.FLOOR_Y,
        };
        const direction = target.sub(enemy.shared.position).normalize();
        enemy.shared.faceLeft = direction.x < 0;
        enemy.shared.velocity = direction.scale(SPEED_DASH);

        audio.playSound("assets/audio/enemy_dash.ogg");
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.dashInAirAnimation.update(delta);
        enemy.dashInAirVfx.update(delta);
        if (enemy.shared.isOnFloor()) enemy.changeState(.idle);
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.dashInAirAnimation);
        const pos = enemy.shared.logicCenter();
        gfx.playSliceFlipX(&enemy.dashInAirVfx, pos, !enemy.shared.faceLeft);
    }

    fn exit(enemy: *Enemy) void {
        enemy.dashInAirAnimation.reset();
        enemy.dashInAirVfx.reset();
        enemy.shared.enableGravity = true;
    }
};

var runSound: *audio.Sound = undefined;
const RunState = struct {
    const SPEED_RUN = 500;
    const MIN_DISTANCE = 350;

    fn enter(enemy: *Enemy) void {
        enemy.state = .run;
        runSound = audio.playSoundLoop("assets/audio/enemy_run.ogg");
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.runAnimation.update(delta);

        const playerX = scene.player.shared.position.x;
        const enemyX = enemy.shared.position.x;
        const direction: f32 = if (playerX > enemyX) 1 else -1;
        enemy.shared.velocity.x = direction * SPEED_RUN;

        if (@abs(playerX - enemyX) > MIN_DISTANCE) return;

        const rand = window.rand.intRangeLessThanBiased(u8, 0, 100);
        if (enemy.isEnraged()) {
            switch (rand) {
                0...74 => enemy.changeState(.throwSilk),
                else => enemy.changeState(.squat),
            }
        } else {
            switch (rand) {
                0...74 => enemy.changeState(.squat),
                else => enemy.changeState(.throwSilk),
            }
        }
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.runAnimation);
    }

    fn exit(enemy: *Enemy) void {
        enemy.runAnimation.reset();
        enemy.shared.velocity = .zero;
        audio.stopSound(runSound);
    }
};

const SquatState = struct {
    fn enter(enemy: *Enemy) void {
        enemy.state = .squat;
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.squatAnimation.update(delta);
        if (enemy.squatTimer.isRunningAfterUpdate(delta)) return;

        enemy.changeState(.dashOnFloor);
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.squatAnimation);
    }

    fn exit(enemy: *Enemy) void {
        enemy.squatAnimation.reset();
        enemy.squatTimer.reset();
    }
};

const DashOnFloorState = struct {
    const SPEED_DASH = 1000;

    fn enter(enemy: *Enemy) void {
        enemy.state = .dashOnFloor;
        const direction: f32 = if (enemy.shared.faceLeft) -1 else 1;
        enemy.shared.velocity = .{ .x = direction * SPEED_DASH };

        audio.playSound("assets/audio/enemy_dash.ogg");
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.dashOnFloorAnimation.update(delta);
        enemy.dashOnFloorVfx.update(delta);
        if (enemy.dashTimer.isRunningAfterUpdate(delta)) return;

        enemy.changeState(.idle);
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.dashOnFloorAnimation);
        const pos = enemy.shared.logicCenter();
        gfx.playSliceFlipX(&enemy.dashOnFloorVfx, pos, !enemy.shared.faceLeft);
    }

    fn exit(enemy: *Enemy) void {
        enemy.dashOnFloorAnimation.reset();
        enemy.dashOnFloorVfx.reset();
        enemy.dashTimer.reset();
    }
};

const ThrowSilkState = struct {
    fn enter(enemy: *Enemy) void {
        enemy.state = .throwSilk;
        enemy.shared.enableGravity = false;
        enemy.shared.velocity = .zero;
        enemy.silkBox.enable = true;

        audio.playSound("assets/audio/enemy_throw_silk.ogg");
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.throwSilkAnimation.update(delta);
        enemy.silkAnimation.update(delta);
        enemy.silkBox.setCenter(enemy.shared.logicCenter());

        if (enemy.throwSilkTimer.isRunningAfterUpdate(delta)) return;

        if (enemy.shared.isOnFloor()) return enemy.changeState(.idle);

        const rand = window.rand.intRangeLessThanBiased(u8, 0, 100);
        if (!enemy.isEnraged() and rand < 25) {
            enemy.changeState(.aim);
        } else {
            enemy.changeState(.fall);
        }
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.throwSilkAnimation);
        const pos = enemy.shared.logicCenter();
        gfx.playSliceFlipX(&enemy.silkAnimation, pos, !enemy.shared.faceLeft);
    }

    fn exit(enemy: *Enemy) void {
        enemy.throwSilkAnimation.reset();
        enemy.throwSilkTimer.reset();
        enemy.shared.enableGravity = true;
        enemy.silkAnimation.reset();
        enemy.silkBox.enable = false;
    }
};

const ThrowSwordState = struct {
    fn enter(enemy: *Enemy) void {
        enemy.state = .throwSword;
        enemy.appearSwordTimer = .init(0.65);
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.throwSwordAnimation.update(delta);

        const shared = &enemy.shared;
        if (enemy.appearSwordTimer) |*appearTimer| {
            if (appearTimer.isFinishedAfterUpdate(delta)) {
                const sword = Sword.init(shared.logicCenter(), shared.faceLeft);
                enemy.swords.appendAssumeCapacity(sword);
                enemy.appearSwordTimer = null;
                audio.playSound("assets/audio/enemy_throw_sword.ogg");
            }
        }

        if (enemy.throwSwordTimer.isRunningAfterUpdate(delta)) return;

        const rand = window.rand.intRangeLessThanBiased(u8, 0, 100);
        if (enemy.isEnraged()) {
            switch (rand) {
                0...49 => enemy.changeState(.jump),
                50...79 => enemy.changeState(.idle),
                else => enemy.changeState(.idle),
            }
        } else {
            switch (rand) {
                0...49 => enemy.changeState(.squat),
                50...79 => enemy.changeState(.jump),
                else => enemy.changeState(.idle),
            }
        }
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.throwSwordAnimation);
    }

    fn exit(enemy: *Enemy) void {
        enemy.throwSwordAnimation.reset();
        enemy.throwSwordTimer.reset();
    }
};

const ThrowBarbState = struct {
    fn enter(enemy: *Enemy) void {
        enemy.state = .throwBarb;
    }

    fn update(enemy: *Enemy, delta: f32) void {
        enemy.throwBarbAnimation.update(delta);

        if (enemy.throwBarbTimer.isRunningAfterUpdate(delta)) return;

        audio.playSound("assets/audio/enemy_throw_barbs.ogg");
        var number = window.rand.intRangeLessThanBiased(u8, 3, 6);
        if (enemy.barbs.len > 10) number = 1;
        const widthGrid: f32 = window.width / @as(f32, @floatFromInt(number));

        for (0..number) |index| {
            const start = widthGrid * @as(f32, @floatFromInt(index));
            const x: f32 = window.randomFloat(start, widthGrid + start);
            const y: f32 = window.randomFloat(250, 500);
            const barb = Barb.init(.{ .x = x, .y = y });
            enemy.barbs.appendAssumeCapacity(barb);
        }

        enemy.changeState(.idle);
    }

    fn render(enemy: *const Enemy) void {
        enemy.play(&enemy.throwBarbAnimation);
    }

    fn exit(enemy: *Enemy) void {
        enemy.throwBarbAnimation.reset();
        enemy.throwBarbTimer.reset();
    }
};
