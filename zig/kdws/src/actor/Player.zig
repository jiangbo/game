const std = @import("std");

const gfx = @import("../graphics.zig");
const math = @import("../math.zig");
const window = @import("../window.zig");
const audio = @import("../audio.zig");
const SharedActor = @import("actor.zig").SharedActor;
const scene = @import("../scene.zig");

const Player = @This();
const AttackDirection = enum { left, right, up, down };

shared: SharedActor,

state: State,
leftKeyDown: bool = false,
rightKeyDown: bool = false,
jumpKeyDown: bool = false,

idleAnimation: gfx.AtlasFrameAnimation,
runAnimation: gfx.AtlasFrameAnimation,
jumpAnimation: gfx.AtlasFrameAnimation,
fallAnimation: gfx.AtlasFrameAnimation,

rollKeyDown: bool = false,
rollAnimation: gfx.AtlasFrameAnimation,
rollTimer: window.Timer = .init(0.35),
rollCoolDown: window.Timer = .init(0.75),

attackKeyDown: bool = false,
attackPosition: ?math.Vector = null,
attackAnimation: gfx.AtlasFrameAnimation,
attackLeft: gfx.AtlasFrameAnimation,
attackRight: gfx.AtlasFrameAnimation,
attackUp: gfx.AtlasFrameAnimation,
attackDown: gfx.AtlasFrameAnimation,
attackTimer: window.Timer = .init(0.3),
attackCoolDown: window.Timer = .init(0.5),
attackDirection: AttackDirection = .left,

deadTimer: window.Timer = .init(2),
deadAnimation: gfx.AtlasFrameAnimation,

jumpVfxAnimation: gfx.AtlasFrameAnimation,
jumpPosition: math.Vector = .{},
landVfxAnimation: gfx.AtlasFrameAnimation,
landPosition: math.Vector = .{},

pub fn init() Player {
    var shared: SharedActor = .init(200);
    shared.logicHeight = 120;

    shared.hitBox.rect = .{ .w = 150, .h = 150 };
    shared.hitBox.dst = .enemy;
    shared.hitBox.enable = false;

    shared.hurtBox.rect = .{ .w = 40, .h = 80 };
    shared.hurtBox.src = .player;
    shared.hurtBox.callback = struct {
        fn callback() void {
            if (scene.player.shared.hurtIf()) {
                audio.playSound("assets/audio/player_hurt.ogg");
            }
        }
    }.callback;

    var player: Player = .{
        .shared = shared,

        .idleAnimation = .load("assets/player/idle.png", 5),
        .runAnimation = .load("assets/player/run.png", 10),
        .jumpAnimation = .load("assets/player/jump.png", 5),
        .fallAnimation = .load("assets/player/fall.png", 5),

        .state = .idle,
        .rollAnimation = .load("assets/player/roll.png", 7),
        .attackAnimation = .load("assets/player/attack.png", 5),
        .deadAnimation = .load("assets/player/dead.png", 6),

        .attackLeft = .load("assets/player/vfx_attack_left.png", 5),
        .attackRight = .load("assets/player/vfx_attack_right.png", 5),
        .attackUp = .load("assets/player/vfx_attack_up.png", 5),
        .attackDown = .load("assets/player/vfx_attack_down.png", 5),

        .jumpVfxAnimation = .load("assets/player/vfx_jump.png", 5),
        .landVfxAnimation = .load("assets/player/vfx_land.png", 2),
    };

    player.idleAnimation.timer = .init(0.15);

    player.runAnimation.loop = true;
    player.runAnimation.timer = .init(0.075);

    player.jumpAnimation.loop = false;
    player.jumpAnimation.timer = .init(0.15);

    player.fallAnimation.loop = false;
    player.fallAnimation.timer = .init(0.15);

    player.rollAnimation.loop = false;
    player.rollAnimation.timer = .init(0.05);

    player.attackAnimation.loop = false;
    player.attackAnimation.timer = .init(0.05);

    player.deadAnimation.loop = false;
    player.deadAnimation.timer = .init(0.1);
    player.deadAnimation.timer.finished = true;

    player.attackLeft.loop = false;
    player.attackLeft.timer = .init(0.07);
    player.attackLeft.anchor = .centerCenter;
    player.attackRight.loop = false;
    player.attackRight.timer = .init(0.07);
    player.attackRight.anchor = .centerCenter;
    player.attackUp.loop = false;
    player.attackUp.timer = .init(0.07);
    player.attackUp.anchor = .centerCenter;
    player.attackDown.loop = false;
    player.attackDown.timer = .init(0.07);
    player.attackDown.anchor = .centerCenter;

    player.jumpVfxAnimation.loop = false;
    player.jumpVfxAnimation.timer = .init(0.05);
    player.jumpVfxAnimation.timer.finished = true;
    player.landVfxAnimation.loop = false;
    player.landVfxAnimation.timer = .init(0.1);
    player.landVfxAnimation.timer.finished = true;

    return player;
}

pub fn deinit() void {}

pub fn event(self: *Player, ev: *const window.Event) void {
    if (self.shared.health <= 0) return;

    if (ev.type == .KEY_DOWN) {
        switch (ev.key_code) {
            .A, .LEFT => self.leftKeyDown = true,
            .D, .RIGHT => self.rightKeyDown = true,
            .W, .UP => self.jumpKeyDown = true,
            .F => self.attackKeyDown = true,
            .S, .DOWN, .SPACE => self.rollKeyDown = true,
            else => {},
        }
    } else if (ev.type == .KEY_UP) {
        switch (ev.key_code) {
            .A, .LEFT => self.leftKeyDown = false,
            .D, .RIGHT => self.rightKeyDown = false,
            .W, .UP => self.jumpKeyDown = false,
            .F => self.attackKeyDown = false,
            .S, .DOWN, .SPACE => self.rollKeyDown = false,
            else => {},
        }
    }

    if (ev.type == .MOUSE_DOWN) {
        if (ev.mouse_button == .LEFT) {
            self.attackKeyDown = true;
            self.attackPosition = .{ .x = ev.mouse_x, .y = ev.mouse_y };
        } else if (ev.mouse_button == .RIGHT) {
            audio.playSound("assets/audio/bullet_time.ogg");
            scene.bulletTime = true;
        }
    } else if (ev.type == .MOUSE_UP) {
        if (ev.mouse_button == .LEFT) {
            self.attackKeyDown = false;
            self.attackPosition = null;
        } else if (ev.mouse_button == .RIGHT) {
            audio.playSound("assets/audio/bullet_time.ogg");
            scene.bulletTime = false;
        }
    }
}

pub fn update(self: *Player, delta: f32) void {
    self.rollCoolDown.update(delta);
    self.attackCoolDown.update(delta);

    self.jumpVfxAnimation.update(delta);
    self.landVfxAnimation.update(delta);

    self.shared.update(delta);
    self.state.update(self, delta);
}

pub fn render(self: *const Player) void {
    if (self.jumpVfxAnimation.timer.isRunning()) {
        gfx.playAtlas(&self.jumpVfxAnimation, self.jumpPosition);
    }

    if (self.landVfxAnimation.timer.isRunning()) {
        gfx.playAtlas(&self.landVfxAnimation, self.landPosition);
    }

    if (self.shared.isInvulnerable) {
        if (self.shared.isBlink) self.state.render(self);
    } else {
        self.state.render(self);
    }

    const heart = gfx.loadTexture("assets/ui_heart.png");
    var x: f32 = 0;
    for (0..self.shared.health) |index| {
        x = 10 + @as(f32, @floatFromInt(index)) * 40;
        gfx.draw(heart, x, 10);
    }
}

fn changeState(self: *Player, new: State) void {
    self.state.exit(self);
    new.enter(self);
}

fn play(self: *const Player, animation: *const gfx.AtlasFrameAnimation) void {
    gfx.playAtlasFlipX(animation, self.shared.position, self.shared.faceLeft);
}

fn canAttack(self: *const Player) bool {
    return self.attackKeyDown and self.attackCoolDown.finished;
}

const State = union(enum) {
    idle: IdleState,
    run: RunState,
    jump: JumpState,
    fall: FallState,
    roll: RollState,
    attack: AttackState,
    dead: DeadState,

    fn enter(self: State, player: *Player) void {
        switch (self) {
            inline else => |case| @TypeOf(case).enter(player),
        }
    }

    fn update(self: State, player: *Player, delta: f32) void {
        if (player.shared.health <= 0 and player.state != .dead) {
            player.changeState(.dead);
        }

        switch (self) {
            inline else => |case| @TypeOf(case).update(player, delta),
        }
    }

    fn render(self: State, player: *const Player) void {
        switch (self) {
            inline else => |case| @TypeOf(case).render(player),
        }
    }

    fn exit(self: State, player: *Player) void {
        switch (self) {
            inline else => |case| @TypeOf(case).exit(player),
        }
    }
};

const IdleState = struct {
    fn enter(player: *Player) void {
        player.state = .idle;
        player.shared.velocity.x = 0;
    }

    fn update(player: *Player, delta: f32) void {
        if (player.attackKeyDown and player.attackCoolDown.finished) {
            player.changeState(.attack);
        } else if (player.shared.velocity.y > 0) {
            player.changeState(.fall);
        } else if (player.jumpKeyDown and player.shared.isOnFloor()) {
            player.changeState(.jump);
        } else if (player.rollKeyDown and player.rollCoolDown.finished) {
            player.changeState(.roll);
        } else if (player.leftKeyDown or player.rightKeyDown) {
            player.changeState(.run);
        }

        player.idleAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.idleAnimation);
    }

    fn exit(player: *Player) void {
        player.idleAnimation.reset();
    }
};

const JumpState = struct {
    const SPEED_JUMP = 780;

    fn enter(player: *Player) void {
        player.state = .jump;
        player.shared.velocity.y = -SPEED_JUMP;
        player.jumpPosition = player.shared.position;
        player.jumpVfxAnimation.reset();

        audio.playSound("assets/audio/player_jump.ogg");
    }

    fn update(player: *Player, delta: f32) void {
        if (player.shared.velocity.y > 0) player.changeState(.fall);

        if (player.canAttack()) player.changeState(.attack);

        player.jumpAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.jumpAnimation);
    }

    fn exit(player: *Player) void {
        player.jumpAnimation.reset();
    }
};

const FallState = struct {
    fn enter(player: *Player) void {
        player.state = .fall;
    }

    fn update(player: *Player, delta: f32) void {
        if (player.shared.isOnFloor()) {
            player.changeState(.idle);
            player.landPosition = player.shared.position;
            player.landVfxAnimation.reset();
            audio.playSound("assets/audio/player_land.ogg");
        }

        if (player.canAttack()) player.changeState(.attack);

        player.fallAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.fallAnimation);
    }

    fn exit(player: *Player) void {
        player.fallAnimation.reset();
    }
};

var runSound: *audio.Sound = undefined;
const RunState = struct {
    const SPEED_RUN = 300;

    fn enter(player: *Player) void {
        player.state = .run;

        if (player.leftKeyDown) {
            player.shared.velocity.x = -SPEED_RUN;
            player.shared.faceLeft = true;
        } else if (player.rightKeyDown) {
            player.shared.velocity.x = SPEED_RUN;
            player.shared.faceLeft = false;
        }

        runSound = audio.playSoundLoop("assets/audio/player_run.ogg");
    }

    fn update(player: *Player, delta: f32) void {
        if (player.canAttack()) {
            player.changeState(.attack);
        }

        if (!player.leftKeyDown and !player.rightKeyDown) {
            player.changeState(.idle);
        }

        if (player.rollKeyDown and player.rollCoolDown.finished) {
            player.changeState(.roll);
        }

        if (player.jumpKeyDown and player.shared.velocity.y == 0) {
            player.changeState(.jump);
        }

        player.runAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.runAnimation);
    }

    fn exit(player: *Player) void {
        player.runAnimation.reset();
        audio.stopSound(runSound);
    }
};

const RollState = struct {
    const SPEED_ROLL = 800;
    fn enter(player: *Player) void {
        player.state = .roll;
        player.rollTimer.reset();
        player.rollCoolDown.reset();

        const direction: f32 = if (player.shared.faceLeft) -1 else 1;
        player.shared.velocity.x = SPEED_ROLL * direction;

        player.shared.hurtBox.enable = false;
        audio.playSound("assets/audio/player_roll.ogg");
    }

    fn update(player: *Player, delta: f32) void {
        if (player.rollTimer.isFinishedAfterUpdate(delta)) {
            player.changeState(.idle);
        }

        player.rollAnimation.update(delta);
    }

    fn render(player: *const Player) void {
        player.play(&player.rollAnimation);
    }

    fn exit(player: *Player) void {
        player.rollAnimation.reset();
        player.shared.hurtBox.enable = true;
    }
};

const AttackState = struct {
    fn enter(player: *Player) void {
        player.state = .attack;
        player.attackTimer.reset();
        player.attackCoolDown.reset();

        if (player.attackPosition) |pos| {
            // 下面的公式根据教程编写，没有具体探究为什么
            const angle = pos.sub(player.shared.logicCenter()).angle();
            const half = std.math.pi / 4.0;
            player.attackDirection = if (angle > -half and angle < half) .right //
                else if (angle > half and angle < 3 * half) .down //
                else if ((angle > 3 * half and angle < std.math.pi) or //
                (angle > -std.math.pi and angle < -3 * half)) .left //
                else .up;
        } else {
            player.attackDirection = if (player.shared.faceLeft) .left else .right;
        }

        switch (window.rand.intRangeAtMostBiased(u8, 1, 3)) {
            1 => audio.playSound("assets/audio/player_attack_1.ogg"),
            2 => audio.playSound("assets/audio/player_attack_2.ogg"),
            3 => audio.playSound("assets/audio/player_attack_3.ogg"),
            else => unreachable,
        }
    }

    fn update(player: *Player, delta: f32) void {
        if (player.attackTimer.isFinishedAfterUpdate(delta)) {
            return if (player.shared.velocity.y > 0) {
                player.changeState(.fall);
            } else {
                player.changeState(.idle);
            };
        }

        player.attackAnimation.update(delta);
        updateHitBox(player, delta);
    }

    fn updateHitBox(player: *Player, delta: f32) void {
        var hitBox = player.shared.hitBox;
        hitBox.enable = true;
        hitBox.setCenter(player.shared.logicCenter());

        switch (player.attackDirection) {
            .left => {
                hitBox.rect.x -= hitBox.rect.w / 2;
                player.attackLeft.update(delta);
                player.shared.faceLeft = true;
            },
            .right => {
                hitBox.rect.x += hitBox.rect.w / 2;
                player.attackRight.update(delta);
                player.shared.faceLeft = false;
            },
            .up => {
                hitBox.rect.y -= hitBox.rect.h / 2;
                player.attackUp.update(delta);
            },
            .down => {
                hitBox.rect.y += hitBox.rect.h / 2;
                player.attackDown.update(delta);
            },
        }
    }

    fn render(player: *const Player) void {
        player.play(&player.attackAnimation);

        const position = player.shared.logicCenter();
        gfx.playAtlas(directionAnimation(@constCast(player)), position);
    }

    fn exit(player: *Player) void {
        player.attackAnimation.reset();
        directionAnimation(player).reset();
        player.shared.hitBox.enable = false;
    }

    fn directionAnimation(player: *Player) *gfx.AtlasFrameAnimation {
        return switch (player.attackDirection) {
            .left => &player.attackLeft,
            .right => &player.attackRight,
            .up => &player.attackUp,
            .down => &player.attackDown,
        };
    }
};

const DeadState = struct {
    fn enter(player: *Player) void {
        player.state = .dead;
        player.deadTimer.reset();
        audio.playSound("assets/audio/player_dead.ogg");
    }

    fn update(player: *Player, delta: f32) void {
        player.deadAnimation.update(delta);
        if (player.deadTimer.isRunningAfterUpdate(delta)) return;

        std.log.info("player dead", .{});
        window.exit();
    }

    fn render(player: *const Player) void {
        player.play(&player.deadAnimation);
    }

    fn exit(player: *Player) void {
        player.deadAnimation.reset();
    }
};
