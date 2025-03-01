const std = @import("std");
const gfx = @import("graphics.zig");
const animation = @import("animation.zig");
const cache = @import("cache.zig");
const context = @import("context.zig");
const window = @import("window.zig");
const math = @import("math.zig");

pub const Bullet = struct {
    x: f32 = 0,
    y: f32 = 0,
    texture: gfx.Texture,

    pub const radialSpeed: f32 = 0.0045;
    pub const tangentSpeed: f32 = 0.0055;
};

pub const Player = struct {
    x: f32 = 500,
    y: f32 = 500,
    speed: f32 = 0.4,
    faceLeft: bool = true,
    animation: animation.FrameAnimation,
    shadow: gfx.Texture,
    moveUp: bool = false,
    moveDown: bool = false,
    moveLeft: bool = false,
    moveRight: bool = false,
    score: u32 = 0,

    bullets: [3]Bullet = undefined,

    pub fn init() Player {
        const leftFmt: []const u8 = "assets/img/player_left_{}.png";
        const left = animation.FixedSizeFrameAnimation.load(leftFmt, 50).?;

        const rightFmt = "assets/img/player_right_{}.png";
        const right = animation.FixedSizeFrameAnimation.load(rightFmt, 50).?;

        var self = Player{
            .animation = .{ .left = left, .right = right },
            .shadow = cache.TextureCache.load("assets/img/shadow_player.png").?,
        };

        const tex = cache.TextureCache.load("assets/img/bullet.png").?;
        for (&self.bullets) |*bullet| {
            bullet.* = Bullet{ .x = -tex.width, .y = -tex.height, .texture = tex };
        }

        return self;
    }

    pub fn processEvent(self: *Player, event: *const window.Event) void {
        if (event.type == .KEY_DOWN) switch (event.key_code) {
            .W => self.moveUp = true,
            .S => self.moveDown = true,
            .A => self.moveLeft = true,
            .D => self.moveRight = true,
            else => {},
        } else if (event.type == .KEY_UP) switch (event.key_code) {
            .W => self.moveUp = false,
            .S => self.moveDown = false,
            .A => self.moveLeft = false,
            .D => self.moveRight = false,
            else => {},
        };
    }

    pub fn update(self: *Player, delta: f32) void {
        var vector2: math.Vector2 = .{};
        if (self.moveUp) vector2.y -= 1;
        if (self.moveDown) vector2.y += 1;
        if (self.moveLeft) vector2.x -= 1;
        if (self.moveRight) vector2.x += 1;

        const normalized = vector2.normalize();
        self.x += normalized.x * delta * self.speed;
        self.y += normalized.y * delta * self.speed;

        self.x = std.math.clamp(self.x, 0, context.width - self.currentTexture().width);
        self.y = std.math.clamp(self.y, 0, context.height - self.currentTexture().height);

        if (self.moveLeft) self.faceLeft = true;
        if (self.moveRight) self.faceLeft = false;

        if (self.faceLeft)
            self.animation.left.play(delta)
        else
            self.animation.right.play(delta);

        self.updateBullets();
    }

    fn updateBullets(self: *Player) void {
        const len: f32 = @floatFromInt(self.bullets.len);
        const radianInterval = 2 * std.math.pi / len;

        const total = window.totalMillisecond();
        const radius = 100 + 25 * @sin(total * Bullet.radialSpeed);

        const playerCenterX = self.x + self.currentTexture().width / 2;
        const playerCenterY = self.y + self.currentTexture().height / 2;

        for (0..self.bullets.len) |i| {
            const pos = radianInterval * @as(f32, @floatFromInt(i));
            const radian = pos + total * Bullet.tangentSpeed;
            self.bullets[i].x = playerCenterX + radius * @sin(radian);
            self.bullets[i].y = playerCenterY + radius * @cos(radian);
        }
    }

    pub fn currentTexture(self: Player) gfx.Texture {
        return if (self.faceLeft)
            self.animation.left.currentTexture()
        else
            self.animation.right.currentTexture();
    }

    pub fn shadowX(self: *Player) f32 {
        const w = self.currentTexture().width - self.shadow.width;
        return self.x + w / 2;
    }

    pub fn shadowY(self: *Player) f32 {
        return self.y + self.currentTexture().height - 8;
    }
};

pub const Enemy = struct {
    x: f32 = 0,
    y: f32 = 0,
    animation: animation.FrameAnimation,
    shadow: gfx.Texture,
    faceLeft: bool = true,
    speed: f32 = 0.1,

    pub fn init() Enemy {
        const leftFmt: []const u8 = "assets/img/enemy_left_{}.png";
        const left = animation.FixedSizeFrameAnimation.load(leftFmt, 50).?;

        const rightFmt = "assets/img/enemy_right_{}.png";
        const right = animation.FixedSizeFrameAnimation.load(rightFmt, 50).?;

        return Enemy{
            .animation = .{ .left = left, .right = right },
            .shadow = cache.TextureCache.load("assets/img/shadow_enemy.png").?,
        };
    }

    pub fn update(self: *Enemy, delta: f32, player: Player) void {
        const playerPos = math.Vector2{ .x = player.x, .y = player.y };
        const enemyPos = math.Vector2{ .x = self.x, .y = self.y };
        const normalized = playerPos.sub(enemyPos).normalize();

        self.x += normalized.x * delta * self.speed;
        self.y += normalized.y * delta * self.speed;

        self.faceLeft = normalized.x < 0;

        if (self.faceLeft)
            self.animation.left.play(delta)
        else
            self.animation.right.play(delta);
    }

    pub fn currentTexture(self: Enemy) gfx.Texture {
        return if (self.faceLeft)
            self.animation.left.currentTexture()
        else
            self.animation.right.currentTexture();
    }

    pub fn shadowX(self: Enemy) f32 {
        const width = self.currentTexture().width - self.shadow.width;
        return self.x + width / 2;
    }

    pub fn shadowY(self: Enemy) f32 {
        return self.y + self.currentTexture().height - 25;
    }
};
