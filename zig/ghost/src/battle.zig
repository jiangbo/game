const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;

const scene = @import("scene.zig");
const world = @import("world.zig");
const player = @import("player.zig");
const enemy = @import("enemy.zig");
const menu = @import("menu.zig");

pub const Stats = struct {
    health: u32 = 100, // 生命值
    maxHealth: u32 = 100, // 最大生命值
    attack: u32 = 40, // 攻击力
};

const circle = zhu.graphics.imageId("circle.png"); // 显示碰撞范围
const spellFrames = zhu.graphics.framesX(13, .xy(64, 64), 0.1);
const spellDamageIndex = 6; // 动画第 6 帧造成伤害，视觉效果好一点
const spellSize = spellFrames[0].area.size.scale(3);

var spellTimer: zhu.window.Timer = .init(2);
var spellAnimations: [4]zhu.graphics.FrameAnimation = undefined;
var spellPositions: [4]zhu.Vector2 = undefined;
var mana: u32 = 100;
var manaTimer: zhu.window.Timer = .init(1); // 每秒回复一次魔法值

pub var highScore: u32 = 0;
var score: u32 = 0;

pub fn init() void {
    const image = zhu.graphics.getImage("effect/Thunderstrike w blur.png");
    for (&spellAnimations) |*a| a.* = .initFinished(image, &spellFrames);
    spellTimer.stop(); // 一开始就可以直接使用魔法
}

pub fn enter() void {
    mana = 100;
    spellTimer.stop();
    score = 0;
    world.paused = false;
    menu.menuIndex = 1;
}

pub fn update(delta: f32) void {
    if (menu.update()) |event| {
        switch (event) {
            0 => world.togglePause(), // 暂停/继续游戏
            1 => scene.changeScene(.world), // 重新开始游戏
            2 => scene.changeScene(.title), // 返回标题界面
            else => unreachable,
        }
        return;
    }

    if (world.paused) return;

    spellTimer.update(delta);
    if (manaTimer.isFinishedLoopUpdate(delta)) {
        mana += 10;
        if (mana > 100) mana = 100;
    }

    // 角色使用魔法
    const canCastSpell = zhu.window.isMouseRelease(.LEFT);
    if (canCastSpell and player.stats.health > 0) {
        playerCastSpell(camera.toWorld(zhu.window.mousePosition));
    }

    for (&spellPositions, &spellAnimations) |pos, *animation| {
        if (animation.isFinished()) continue;

        // 如果动画状态未改变，或者不是伤害帧则跳过
        const changed = animation.isNextOnceUpdate(delta);
        if (!changed or animation.index != spellDamageIndex) continue;

        for (enemy.enemies.items) |*e| {
            const state = e.animation.getEnumState(enemy.State);
            if (state == .dead) continue; // 死亡状态不检测碰撞

            const len = (spellSize.x + enemy.size.x) * 0.5;
            const len2 = pos.sub(e.position).length2();
            if (len2 < len * len) {
                // 命中敌人，造成伤害
                e.stats.health -|= player.stats.attack;
                if (e.stats.health == 0) {
                    score += 1;
                    e.animation = enemy.animations.get(.dead);
                } else e.animation = enemy.animations.get(.hurt);
            }
        }
    }
}

pub fn saveHighScore() void {
    if (score > highScore) {
        highScore = score;
        const bytes = std.mem.toBytes(score);
        zhu.window.saveAll("high.save", &bytes) catch {
            std.log.info("save high score error", .{});
        };
    }
}

fn playerCastSpell(position: zhu.Vector2) void {
    if (mana < 30 or spellTimer.isRunning()) return;

    // 播放攻击音效
    zhu.audio.playSound("assets/sound/big-thunder.ogg");
    for (&spellPositions, &spellAnimations) |*pos, *animation| {
        if (animation.isFinished()) {
            pos.* = position;
            animation.reset();
            mana -= 30;
            spellTimer.elapsed = 0;
            return;
        }
    }
}

pub fn draw() void {
    for (&spellPositions, &spellAnimations) |pos, animation| {
        if (animation.isFinished()) continue;

        const image = animation.currentImage();
        camera.drawImage(image, pos, .{
            .anchor = .center,
            .size = spellSize,
        });
    }
}

const imageId = zhu.graphics.imageId;

pub fn drawUI() void {
    menu.draw();

    // 生命值
    var pos: zhu.Vector2 = .xy(30, 30);
    var option: camera.Option = .{ .anchor = .xy(0, 0.5) };

    const stats = player.stats;
    option.size = .xy(198, 21);
    camera.drawOption(imageId("UI/bar_bg.png"), pos.addX(30), option);
    var percent = zhu.math.percentInt(stats.health, stats.maxHealth);
    option.size.?.x = option.size.?.x * percent;
    camera.drawOption(imageId("UI/bar_red.png"), pos.addX(30), option);
    option.size = .xy(36, 39);
    camera.drawOption(imageId("UI/Red Potion.png"), pos, option);

    // 法力值
    pos = .xy(300, 30);
    option.size = .xy(198, 21);
    camera.drawOption(imageId("UI/bar_bg.png"), pos.addX(30), option);
    percent = zhu.math.percentInt(mana, 100);
    option.size.?.x = option.size.?.x * percent;
    camera.drawOption(imageId("UI/bar_blue.png"), pos.addX(30), option);
    option.size = .xy(36, 39);
    camera.drawOption(imageId("UI/Blue Potion.png"), pos, option);

    // 冷却时间
    const image = zhu.graphics.getImage("UI/Electric-Icon.png");
    var size = image.area.size.scale(0.14);
    pos = .xy(zhu.window.logicSize.x - 300, 30 - size.y / 2);
    camera.drawImage(image, pos, .{ .size = size });

    size.y = size.y * (1 - spellTimer.progress());
    camera.drawRect(.init(pos, size), .{ .color = .gray(0, 100) });

    // 得分
    pos = .xy(zhu.window.logicSize.x - 210, 6);
    camera.drawOption(imageId("UI/Textfield_01.png"), pos, .{
        .size = .xy(200, 48),
    });
    zhu.text.drawFmt("Score: {}", pos.addXY(10, 7), .{score});
}
