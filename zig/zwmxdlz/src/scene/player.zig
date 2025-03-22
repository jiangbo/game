const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");
const Bullet = @import("bullet.zig").Bullet;
const Vector = @import("bullet.zig").Vector;

pub const Player = struct {
    x: f32,
    y: f32,
    facingLeft: bool,
    leftKeyDown: bool = false,
    rightKeyDown: bool = false,
    velocity: Vector = .{},
    width: f32 = 96,
    height: f32 = 96,
    p1: bool = true,

    attackTimer: window.Timer = .init(attackInterval),
    attackExTimer: window.Timer = .init(2500),
    sunTextTimer: window.Timer = .init(2500),

    invulnerableTimer: window.Timer = .init(750),
    invulnerableToggleTimer: window.Timer = .init(75),
    invulnerable: bool = false,
    invulnerableToggle: bool = false,

    hp: u32 = 100,
    mp: u32 = 0,

    textureIdle: gfx.Texture = undefined,
    animationIdle: gfx.FrameAnimation = undefined,
    animationRun: gfx.FrameAnimation = undefined,
    animationAttack: gfx.FrameAnimation = undefined,
    animationSunText: gfx.FrameAnimation = undefined,

    animationJump: gfx.FrameAnimation = undefined,
    positionJump: Vector = .{},
    jumpVisible: bool = false,

    animationLand: gfx.FrameAnimation = undefined,
    positionLand: Vector = .{},
    landVisible: bool = false,

    particles: std.BoundedArray(Particle, 32) = undefined,
    particleTimer: window.Timer = .init(75),

    cursorVisible: bool = true,
    cursorTimer: window.Timer = undefined,
    cursorP1: gfx.Texture = undefined,
    cursorP2: gfx.Texture = undefined,

    hurtDirection: Vector = .{},

    const runVelocity: f32 = 0.55;
    const gravity: f32 = 1.6e-3;
    const jumpVelocity: f32 = -0.85;
    const attackInterval: f32 = 500;
    const attackIntervalEx: f32 = 200;

    pub fn init(playerType: scene.PlayerType, x: f32, y: f32, faceLeft: bool) Player {
        var self: Player = .{ .x = x, .y = y, .facingLeft = faceLeft };
        self.attackExTimer.finished = true;
        self.sunTextTimer.finished = true;
        self.invulnerableTimer.finished = true;
        self.invulnerableToggleTimer.finished = true;

        self.cursorVisible = true;
        self.cursorTimer = window.Timer.init(2500);
        self.cursorP1 = gfx.loadTexture("assets/1P_cursor.png").?;
        self.cursorP2 = gfx.loadTexture("assets/2P_cursor.png").?;

        if (playerType == .peaShooter) {
            self.animationIdle = .load("assets/peashooter_idle_{}.png", 9);
            self.animationRun = .load("assets/peashooter_run_{}.png", 5);
            self.animationAttack = .load("assets/peashooter_attack_ex_{}.png", 3);

            self.textureIdle = whiteTexture("assets/peashooter_idle_1.png");
        } else {
            self.animationIdle = .load("assets/sunflower_idle_{}.png", 8);
            self.animationRun = .load("assets/sunflower_run_{}.png", 5);
            self.animationAttack = .load("assets/sunflower_attack_ex_{}.png", 9);
            self.animationSunText = .load("assets/sun_text_{}.png", 5);

            self.textureIdle = whiteTexture("assets/sunflower_idle_1.png");
        }

        self.animationJump = .load("assets/jump_effect_{}.png", 5);
        self.animationJump.loop = false;
        self.animationLand = .load("assets/land_effect_{}.png", 2);
        self.animationLand.loop = false;
        self.particles = std.BoundedArray(Particle, 32).init(0) catch unreachable;

        return self;
    }

    pub fn event(self: *Player, ev: *const window.Event) void {
        if (self.attackExTimer.isRunning() and ev.type == .KEY_DOWN) return;

        switch (ev.type) {
            .KEY_DOWN => switch (ev.key_code) {
                .A, .LEFT => {
                    self.leftKeyDown = true;
                    self.facingLeft = true;
                },
                .D, .RIGHT => {
                    self.rightKeyDown = true;
                    self.facingLeft = false;
                },
                .W, .UP => {
                    if (self.velocity.y != 0) return;
                    self.velocity.y += Player.jumpVelocity;
                    self.jumpVisible = true;
                    const x = self.x + self.width / 2 - self.animationJump.textures[0].width / 2;
                    const y = self.y + self.height - self.animationJump.textures[0].height;
                    self.positionJump = .{ .x = x, .y = y };
                    self.animationJump.reset();
                },
                .F, .PERIOD => self.attack(),
                .G, .SLASH => self.attackEx(),
                else => {},
            },
            .KEY_UP => switch (ev.key_code) {
                .A, .LEFT => self.leftKeyDown = false,
                .D, .RIGHT => self.rightKeyDown = false,
                else => {},
            },
            else => {},
        }
    }

    pub fn update(self: *Player, delta: f32) void {
        self.attackTimer.update(delta);
        self.invulnerableUpdate(delta);

        if (self.cursorTimer.isFinishedAfterUpdate(delta)) self.cursorVisible = false;

        {
            var index: usize = self.particles.len;
            while (index > 0) {
                index -= 1;
                var particle = &self.particles.buffer[index];
                particle.update(delta);
                if (!particle.valid) _ = self.particles.swapRemove(index);
            }
        }
        {
            if (self.jumpVisible) {
                self.animationJump.update(delta);
                if (self.animationJump.finished()) self.jumpVisible = false;
            }
            if (self.landVisible) {
                self.animationLand.update(delta);
                if (self.animationLand.finished()) self.landVisible = false;
            }
        }

        if (self.attackExTimer.isRunningAfterUpdate(delta))
            self.animationAttack.update(delta);

        if (self.sunTextTimer.isRunningAfterUpdate(delta))
            self.animationSunText.update(delta);

        if (self.attackExTimer.isRunning()) {
            self.animationAttack.update(delta);
            self.attackExTimer.update(delta);
            if (self.attackExTimer.finished) {
                self.attackTimer.duration = attackInterval;
            } else if (self.attackTimer.finished) {
                window.shakeCamera.restart(5, 100);
                const bullet = self.spawnBullet();
                scene.gameScene.bullets.append(bullet) catch unreachable;
            }
            return;
        }

        var direction: f32 = 0;
        if (self.leftKeyDown) direction -= 1;
        if (self.rightKeyDown) direction += 1;
        self.x += direction * Player.runVelocity * delta;

        if (self.leftKeyDown or self.rightKeyDown) {
            self.animationRun.update(delta);
            if (self.particleTimer.isFinishedAfterUpdate(delta)) {
                self.particleTimer.reset();
                var effect: Particle = .load("assets/run_effect_{}.png", 4, 45);
                effect.x = self.x + self.width / 2 - effect.width / 2;
                effect.y = self.y + self.height - effect.height;
                self.particles.appendAssumeCapacity(effect);
            }
        } else {
            self.animationIdle.update(delta);
        }

        moveAndCollide(self, delta);
        self.x += self.velocity.x * delta;
    }

    fn invulnerableUpdate(self: *Player, delta: f32) void {
        if (self.invulnerableTimer.isFinishedAfterUpdate(delta)) {
            self.invulnerable = false;
            self.invulnerableToggleTimer.reset();
            return;
        }

        if (self.invulnerableToggleTimer.isFinishedAfterUpdate(delta)) {
            self.invulnerableToggle = !self.invulnerableToggle;
            self.invulnerableToggleTimer.reset();
        }
    }

    fn moveAndCollide(self: *Player, delta: f32) void {
        const velocity = self.velocity.y + Player.gravity * delta;
        const y = self.y + velocity * delta;

        const platforms = &scene.gameScene.platforms;
        for (platforms) |*platform| {
            if (self.x + self.width < platform.shape.left) continue;
            if (self.x > platform.shape.right or self.hp == 0) continue;
            if (y + self.height < platform.shape.y) continue;

            const deltaPosY = self.velocity.y * delta;
            const lastFootPosY = self.y + self.height - deltaPosY;

            if (lastFootPosY <= platform.shape.y) {
                self.y = platform.shape.y - self.height;
                defer self.velocity.y = 0;
                if (self.velocity.y == 0) break;

                self.landVisible = true;
                const x = self.x + self.width / 2 - self.animationLand.textures[0].width / 2;
                const height = self.y + self.height - self.animationLand.textures[0].height;
                self.positionLand = .{ .x = x, .y = height };
                self.animationLand.reset();
                break;
            }
        } else {
            self.y = y;
            self.velocity.y = velocity;
        }
    }

    pub fn render(self: *const Player) void {
        if (self.sunTextTimer.isRunning()) {
            const text = self.animationSunText;
            const x = self.x - self.width / 2 + text.textures[0].width / 2;
            const y = self.y - text.textures[0].height;
            text.playFlipX(x, y, self.facingLeft);
        }

        if (self.cursorVisible) {
            const x = self.x + (self.width - self.cursorP1.width) / 2;
            const y = self.y - self.cursorP1.height;
            const cursor = if (self.p1) self.cursorP1 else self.cursorP2;
            gfx.draw(x, y, cursor);
        }

        for (self.particles.slice()) |*particle| particle.render();
        if (self.jumpVisible) {
            self.animationJump.play(self.positionJump.x, self.positionJump.y);
        }
        if (self.landVisible) {
            self.animationLand.play(self.positionLand.x, self.positionLand.y);
        }

        if (self.invulnerable and self.invulnerableToggle) {
            gfx.draw(self.x, self.y, self.textureIdle);
            return;
        }

        if (self.attackExTimer.isRunning()) {
            self.animationAttack.playFlipX(self.x, self.y, self.facingLeft);
        } else if (self.leftKeyDown) {
            self.animationRun.playFlipX(self.x, self.y, true);
        } else if (self.rightKeyDown) {
            self.animationRun.playFlipX(self.x, self.y, false);
        } else {
            self.animationIdle.playFlipX(self.x, self.y, self.facingLeft);
        }
    }

    pub fn attack(self: *Player) void {
        if (self.attackTimer.isRunning()) return;

        var bullet = self.spawnBullet();
        bullet.playShootSound();

        scene.gameScene.bullets.append(bullet) catch unreachable;
    }

    fn spawnBullet(self: *Player) Bullet {
        self.attackTimer.reset();

        var bullet = Bullet.init(self.p1);

        const x: f32 = if (self.facingLeft) self.x else self.x + self.width;
        bullet.position = .{ .x = x - bullet.texture.width / 2, .y = self.y };
        if (self.facingLeft) bullet.velocity.x = -bullet.velocity.x;

        return bullet;
    }

    pub fn attackEx(self: *Player) void {
        if (self.mp < 100) return;

        const playerType = if (self.p1) scene.playerType1 else scene.playerType2;

        if (playerType == .peaShooter) {
            self.attackExTimer.reset();
            self.attackTimer.duration = attackIntervalEx;
        } else {
            var bullet = Bullet.initSunBulletEx();
            const player = if (self.p1)
                scene.gameScene.player2
            else
                scene.gameScene.player1;
            bullet.p1 = self.p1;
            bullet.position.x = player.x + player.width / 2 - bullet.texture.width / 2;
            scene.gameScene.bullets.append(bullet) catch unreachable;
            self.sunTextTimer.reset();
        }

        Bullet.playShootExSound(playerType);
        self.mp = 0;
    }

    pub fn isCollide(self: *Player, bullet: *Bullet) bool {
        if (bullet.type != .sunEx) {
            const pos = bullet.center();
            if (pos.x < self.x or pos.x > self.x + self.width) return false;
            if (pos.y < self.y or pos.y > self.y + self.height) return false;
            return true;
        }

        if (self.x < bullet.position.x) return false;
        if (self.x + self.width > bullet.position.x + bullet.texture.width) return false;
        if (self.y < bullet.position.y) return false;
        if (self.y + self.height > bullet.position.y + bullet.texture.height) return false;
        return true;
    }

    pub fn collideBullet(self: *Player, bullet: *Bullet) void {
        self.invulnerable = true;
        self.invulnerableTimer.reset();

        self.hp -|= bullet.damage;
        const position: Vector = .{ .x = self.x, .y = self.y };
        self.hurtDirection = bullet.position.sub(position);

        if (self.hp == 0) {
            self.velocity.x = if (self.hurtDirection.x < 0) 0.35 else -0.35;
            self.velocity.y = -1;
        }
    }
};

const stbi = @import("stbi");
fn whiteTexture(path: [:0]const u8) gfx.Texture {
    var image = stbi.Image.loadFromFile(path, 4) catch unreachable;
    defer image.deinit();

    for (0..image.data.len / 4) |index| {
        const i = index * 4;
        if (image.data[i + 3] == 0) continue;
        image.data[i + 0] = 255;
        image.data[i + 1] = 255;
        image.data[i + 2] = 255;
    }

    return gfx.Texture.init(image.width, image.height, image.data);
}

const Particle = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32,
    height: f32,
    index: usize = 0,
    timer: f32 = 0,
    lifespan: f32,
    valid: bool = true,

    textures: []const gfx.Texture,

    pub fn load(comptime pathFmt: []const u8, max: u8, lifespan: f32) Particle {
        const frame = gfx.FrameAnimation.load(pathFmt, max);
        return .{
            .textures = frame.textures,
            .width = frame.textures[0].width,
            .height = frame.textures[0].height,
            .lifespan = lifespan,
        };
    }

    pub fn update(self: *Particle, delta: f32) void {
        self.timer += delta;

        if (self.timer < self.lifespan) return;
        self.timer = 0;
        self.index += 1;
        if (self.index >= self.textures.len) {
            self.index = self.textures.len - 1;
            self.valid = false;
        }
    }

    pub fn render(self: *const Particle) void {
        gfx.draw(self.x, self.y, self.textures[self.index]);
    }
};
