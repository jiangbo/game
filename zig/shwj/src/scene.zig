const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

const Chicken = struct {
    position: math.Vector = .{ .x = -50, .y = -50 },
    speed: f32,
    animationRun: gfx.SliceFrameAnimation,
    animationExplosion: gfx.SliceFrameAnimation = undefined,

    alive: bool = true,
    valid: bool = true,
};

const Bullet = struct {
    position: math.Vector,
    velocity: math.Vector,
    radians: f32,
    valid: bool = true,

    const speed = 800;

    pub fn init(position: math.Vector, degree: f32) Bullet {
        const radians = std.math.degreesToRadians(degree);
        const direction: math.Vector = .init(@cos(radians), @sin(radians));
        return .{
            .position = position,
            .velocity = direction.scale(speed),
            .radians = radians,
        };
    }
};

const ChickenArray = std.BoundedArray(Chicken, 1000);
var chickens: ChickenArray = undefined;

var background: gfx.Texture = undefined;
var battery: gfx.Texture = undefined;
var batteryPosition: math.Vector = .{ .x = 640, .y = 600 };
var barrelIdle: gfx.Texture = undefined;
var barrelPosition: math.Vector = .{ .x = 592, .y = 585 };
var barrelPivot: math.Vector = .{ .x = 48, .y = 25 };
var barrelAngle: f32 = -90;
var animationFire: gfx.SliceFrameAnimation = undefined;

var crosshair: gfx.Texture = undefined;
var crosshairPosition: math.Vector = .zero;

var coolDown: bool = true;
var fireKeyDown: bool = false;
var bulletTexture: gfx.Texture = undefined;
var bullets: std.BoundedArray(Bullet, 100) = undefined;

var spawnIntervalTimer: window.Timer = .init(1.5);
var spawnNumberTimer: window.Timer = .init(8);
var spawnNumber: usize = 0;

var health: u8 = 10;
var heart: gfx.Texture = undefined;
var score: usize = 0;
var deadTimer: window.Timer = .init(5);

pub const ShakeCamera = struct {
    position: math.Vector = .zero,
    timer: window.Timer,
    strength: f32 = 0.1,

    pub fn update(self: *ShakeCamera, delta: f32) void {
        if (self.timer.isRunningAfterUpdate(delta)) {
            const offset: math.Vector = .{
                .x = math.randomF32(-50, 50),
                .y = math.randomF32(-50, 50),
            };
            self.position = offset.scale(self.strength);
        } else {
            self.position = .zero;
        }
    }
};

var camera: ShakeCamera = .{ .timer = .init(0.3) };

pub fn init() void {
    window.showCursor(false);

    background = gfx.loadTexture("assets/background.png");
    battery = gfx.loadTexture("assets/battery.png");
    barrelIdle = gfx.loadTexture("assets/barrel_idle.png");
    bulletTexture = gfx.loadTexture("assets/bullet.png");
    crosshair = gfx.loadTexture("assets/crosshair.png");
    chickens = ChickenArray.init(0) catch unreachable;
    bullets = std.BoundedArray(Bullet, 100).init(0) catch unreachable;

    animationFire = .load("assets/barrel_fire_{}.png", 3);
    animationFire.loop = false;
    animationFire.timer.duration = 0.04;

    heart = gfx.loadTexture("assets/heart.png");

    camera.timer.finished = true;

    audio.playMusic("assets/bgm.ogg");
}

pub fn event(ev: *const window.Event) void {
    if (health == 0) return;

    if (ev.type == .MOUSE_DOWN) fireKeyDown = true;
    if (ev.type == .MOUSE_UP) fireKeyDown = false;
    if (ev.type == .KEY_DOWN and ev.key_code == .SPACE) fireKeyDown = true;
    if (ev.type == .KEY_UP and ev.key_code == .SPACE) fireKeyDown = false;

    if (ev.type == .MOUSE_MOVE) {
        crosshairPosition = .init(ev.mouse_x, ev.mouse_y);
        const radians = crosshairPosition.sub(batteryPosition).radians();
        barrelAngle = std.math.radiansToDegrees(radians);
    }
}
pub fn update(delta: f32) void {
    if (health == 0) {
        if (deadTimer.isFinishedAfterUpdate(delta)) {
            window.exit();
        }
        return;
    }

    if (spawnIntervalTimer.isFinishedAfterUpdate(delta)) {
        spawnIntervalTimer.reset();
        spawnChicken();
    }

    if (spawnNumberTimer.isFinishedAfterUpdate(delta)) {
        spawnNumberTimer.reset();
        spawnNumber += 1;
    }

    camera.update(delta);

    if (!coolDown) {
        animationFire.update(delta);
        if (animationFire.finished()) coolDown = true;
    }

    if (coolDown and fireKeyDown) fire();

    {
        var i: usize = bullets.len;
        while (i > 0) : (i -= 1) {
            var bullet: *Bullet = &bullets.buffer[i - 1];
            if (!bullet.valid) {
                _ = bullets.swapRemove(i - 1);
                continue;
            }

            bullet.position = bullet.position.add(bullet.velocity.scale(delta));
            const windowRect: math.Rectangle = .{ .size = window.size };
            if (!windowRect.contains(bullet.position)) bullet.valid = false;
        }
    }

    {
        var i: usize = chickens.len;
        while (i > 0) : (i -= 1) {
            var chicken: *Chicken = &chickens.buffer[i - 1];
            if (!chicken.valid) {
                _ = chickens.swapRemove(i - 1);
                continue;
            }

            if (chicken.alive) {
                chicken.position.y += chicken.speed * delta;
                chicken.animationRun.update(delta);
            } else {
                chicken.animationExplosion.update(delta);
                if (chicken.animationExplosion.finished())
                    chicken.valid = false;
            }

            if (chicken.position.y > window.size.y) {
                chicken.valid = false;
                health -|= 1;
                if (health == 0) {
                    audio.playMusic("assets/loss.ogg");
                } else {
                    audio.playSound("assets/hurt.ogg");
                }
            }
        }
    }

    checkCollision();
}

fn spawnChicken() void {
    for (0..spawnNumber) |_| {
        var chicken: Chicken = switch (math.randomU8(0, 100)) {
            0...49 => .{
                .speed = 80,
                .animationRun = .load("assets/chicken_fast_{}.png", 4),
            },
            50...79 => .{
                .speed = 50,
                .animationRun = .load("assets/chicken_medium_{}.png", 6),
            },
            80...99 => .{
                .speed = 30,
                .animationRun = .load("assets/chicken_slow_{}.png", 8),
            },
            else => unreachable,
        };

        chicken.position = .{ .x = math.randomF32(40, window.size.x - 40) };
        chicken.animationExplosion = .load("assets/explosion_{}.png", 5);
        chicken.animationExplosion.loop = false;
        chicken.animationExplosion.timer.duration = 0.08;

        chickens.append(chicken) catch {
            std.log.info("chicken array is full", .{});
        };
    }
}

fn fire() void {
    animationFire.reset();
    coolDown = false;
    camera.timer.reset();

    const barrelCenter: math.Vector = .{ .x = 640, .y = 610 };

    var bullet: Bullet = .init(barrelCenter, barrelAngle + math.randomF32(-15, 15));
    bullet.position = bullet.position.add(bullet.velocity.scale(105 / Bullet.speed));
    bullets.append(bullet) catch {
        std.log.info("bullet array is full", .{});
    };

    const rand = math.randomU8(1, 4);
    switch (rand) {
        1 => audio.playSound("assets/fire_1.ogg"),
        2 => audio.playSound("assets/fire_2.ogg"),
        3 => audio.playSound("assets/fire_3.ogg"),
        else => unreachable,
    }
}

fn checkCollision() void {
    for (bullets.slice()) |*bullet| {
        if (!bullet.valid) continue;
        for (chickens.slice()) |*chicken| {
            if (!chicken.alive or !chicken.valid) continue;

            const size: math.Vector = .init(30, 40);
            const chickenRect: math.Rectangle = .{
                .size = size,
                .position = chicken.position,
            };

            if (chickenRect.contains(bullet.position)) {
                chicken.alive = false;
                audio.playSound("assets/explosion.ogg");
                bullet.valid = false;
                score += 1;
            }
        }
    }
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.camera.rect.position = camera.position;
    gfx.draw(background, window.size.sub(background.size()).scale(0.5));

    for (chickens.slice()) |*chicken| {
        if (chicken.alive) {
            gfx.playSlice(&chicken.animationRun, chicken.position);
        } else {
            gfx.playSlice(&chicken.animationExplosion, chicken.position);
        }
    }

    for (bullets.slice()) |*bullet| {
        gfx.draw(bulletTexture, bullet.position);
    }

    gfx.draw(battery, batteryPosition.sub(battery.size().scale(0.5)));

    const options: gfx.DrawOptions = .{
        .targetRect = .{ .position = barrelPosition },
        .angle = barrelAngle,
        .pivot = barrelPivot,
    };
    if (coolDown) {
        gfx.drawOptions(barrelIdle, options);
    } else {
        playOptions(&animationFire, options);
    }

    gfx.draw(crosshair, crosshairPosition.sub(crosshair.size().scale(0.5)));

    gfx.camera.rect.position = .zero;
    for (0..health) |index| {
        const x = 15 + (heart.width() + 10) * @as(f32, @floatFromInt(index));
        gfx.draw(heart, .{ .x = x, .y = 15 });
    }

    var buffer: [50]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buffer, "SCORE: {d}", .{score});
    window.displayText(53, 1, text catch unreachable);
    window.endDisplayText();
}

fn playOptions(frame: *const gfx.SliceFrameAnimation, options: gfx.DrawOptions) void {
    const texture = frame.textures[frame.index];
    gfx.drawOptions(texture, options);
}

pub fn deinit() void {}
