const std = @import("std");
const zhu = @import("zhu");

const map = @import("map.zig");
const com = @import("component.zig");
const spawn = @import("spawn.zig");
const battle = @import("battle.zig");
const hud = @import("hud.zig");
const ctx = @import("context.zig");

const system = struct {
    const timer = @import("system/timer.zig");
    const motion = @import("system/motion.zig");
    const state = @import("system/state.zig");
    const target = @import("system/target.zig");
    const skill = @import("system/skill.zig");
    const projectile = @import("system/projectile.zig");
    const attack = @import("system/attack.zig");
    const health = @import("system/health.zig");
    const death = @import("system/death.zig");
    const facing = @import("system/facing.zig");
    const animation = @import("system/animation.zig");
    const selection = @import("system/selection.zig");
};

var clearTimer: ?zhu.Timer = null;
var gameOverTriggered: bool = false;

pub fn init() void {}

pub fn deinit() void {
    spawn.deinit();
}

pub fn enter() void {
    clearTimer = null;
    gameOverTriggered = false;
    ctx.resetBattle();
    map.init(ctx.levelIndex);
    spawn.init();
    zhu.audio.playMusic("assets/audio/4 Battle Track INTRO TomMusic.ogg");
}

pub fn exit() void {
    map.deinit();
}

pub fn restart(reg: *zhu.ecs.Registry) void {
    clearTimer = null;
    gameOverTriggered = false;
    ctx.resetBattle();
    reg.reset();
    spawn.changeLevel(ctx.levelIndex);
    map.init(ctx.levelIndex);
}

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    system.selection.update(reg, delta); // 悬停、选中与范围显示状态
    if (!ctx.uiWantCaptureMouse) {
        if (zhu.window.mouse.pressed(.LEFT)) {
            if (ctx.selectedUnit()) |unit| {
                spawn.tryDeployPlayer(reg, unit);
            }
        } else if (zhu.window.mouse.pressed(.RIGHT)) {
            if (ctx.selected != null) ctx.selected = null;
        }
    }

    if (ctx.paused) return;

    // 地图更新，地图上的动画等。
    spawn.update(reg, delta);
    map.update(delta);

    system.timer.update(reg, delta); // 计时系统
    system.skill.update(reg, delta); // 技能系统
    system.target.update(reg, delta); // 目标系统
    system.motion.update(reg, delta); // 移动系统
    system.state.update(reg, delta); // 状态系统
    system.projectile.update(reg, delta); // 投射物系统
    system.attack.update(reg, delta); // 攻击系统
    system.health.update(reg, delta); // 生命系统
    system.death.update(reg, delta); // 死亡系统
    system.facing.update(reg, delta); // 面向系统
    system.animation.update(reg, delta); // 动画系统

    // 处理到达终点的敌人
    for (reg.getEvents(zhu.ecs.Entity).items) |entity| {
        ctx.enemyArrivedCount += 1;
        ctx.homeHealth -= 1;
        reg.destroyEntity(entity);
    }
    reg.clearEvent(zhu.ecs.Entity);

    // 通关奖励积分 + 启动延迟计时器
    if (!ctx.levelClear and ctx.isLevelClear()) {
        ctx.levelClear = true;
        ctx.point += ctx.reward();
        clearTimer = .init(3);
    }

    // 通关延迟倒计时
    if (clearTimer) |*t| {
        if (t.isFinishedOnceUpdate(delta)) {
            clearTimer = null;
            if (!spawn.hasNextLevel(ctx.levelIndex)) {
                ctx.win = true;
                ctx.pendingScene = .end;
            } else {
                ctx.pendingScene = .clear;
            }
        }
    }

    // 游戏失败检测（仅触发一次）
    if (!gameOverTriggered and ctx.isGameOver()) {
        gameOverTriggered = true;
        ctx.win = false;
        ctx.pendingScene = .end;
    }
}

pub fn draw(reg: *zhu.ecs.Registry) void {
    map.draw();

    reg.sort(com.Position, struct {
        pub fn lessThan(a: com.Position, b: com.Position) bool {
            return a.y < b.y;
        }
    }.lessThan);

    var view = reg.view(.{ com.Position, com.Sprite });
    while (view.next()) |entity| {
        const sprite = view.get(entity, com.Sprite);
        const position = view.get(entity, com.Position);
        const pos = position.add(sprite.offset);

        zhu.batch.drawImage(sprite.image, pos, .{
            .flipX = sprite.flip,
            .size = sprite.size,
        });
    }

    system.health.draw(reg); // 绘制血条
    system.projectile.draw(reg); // 绘制投射物
    system.selection.draw(reg); // 绘制攻击范围和选择调试信息
}
