const ecs = @import("ecs");
const zhu = @import("zhu");

const map = @import("map.zig");
const com = @import("component.zig");
const spawn = @import("spawn.zig");
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

pub fn deinit(allocator: zhu.Allocator) void {
    spawn.deinit(allocator);
}

pub fn enter(allocator: zhu.Allocator) void {
    clearTimer = null;
    gameOverTriggered = false;
    ctx.resetBattle();
    map.init(allocator, ctx.levelIndex);
    spawn.init();
    zhu.audio.playMusic("audio/4 Battle Track INTRO TomMusic.ogg");
}

pub fn exit(allocator: zhu.Allocator) void {
    map.deinit(allocator);
}

pub fn restart(reg: *ecs.World) void {
    clearTimer = null;
    gameOverTriggered = false;
    ctx.resetBattle();
    reg.reset();
    spawn.changeLevel(ctx.levelIndex);
    map.deinit(reg.allocator);
    map.init(reg.allocator, ctx.levelIndex);
}

pub fn update(reg: *ecs.World, delta: f32) void {
    system.selection.update(reg, delta); // 悬停、选中与范围显示状态
    if (!ctx.uiWantCaptureMouse) {
        if (zhu.key.pressed(.MOUSE_LEFT)) {
            if (ctx.selectedUnit()) |unit| {
                spawn.tryDeployPlayer(reg, unit);
            }
        } else if (zhu.key.pressed(.MOUSE_RIGHT)) {
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

    // 到达终点后立即移除，避免继续参加战斗或在编号复用后消费旧事件。
    var arrived = reg.query(.{com.Arrived}).reverse();
    while (arrived.next()) |entity| {
        ctx.enemyArrivedCount += 1;
        ctx.homeHealth -= 1;
        system.death.destroy(reg, entity);
    }

    system.state.update(reg, delta); // 状态系统
    system.projectile.update(reg, delta); // 投射物系统
    system.attack.update(reg, delta); // 攻击系统
    system.health.update(reg, delta); // 生命系统
    system.death.update(reg, delta); // 死亡系统
    system.facing.update(reg, delta); // 面向系统
    system.animation.update(reg, delta); // 动画系统

    // 通关奖励积分 + 启动延迟计时器
    if (!ctx.levelClear and ctx.isLevelClear()) {
        ctx.levelClear = true;
        ctx.point += ctx.reward();
        clearTimer = .init(3);
    }

    // 通关延迟倒计时
    if (clearTimer) |*t| {
        if (t.updateFinished(delta)) {
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

pub fn draw(reg: *ecs.World) void {
    map.draw();

    reg.sort(com.Position, struct {
        pub fn lessThan(a: com.Position, b: com.Position) bool {
            return a.y < b.y;
        }
    }.lessThan);

    var view = reg.queryBy(com.Position, .{com.Sprite}, .{});
    while (view.next()) |entity| {
        const sprite = reg.get(entity, com.Sprite).?;
        const position = reg.get(entity, com.Position).?;
        const pos = position.add(sprite.offset);

        zhu.batch.drawImage(sprite.image, pos, .{
            .uvRect = sprite.image.uvFlip(sprite.flip, false),
            .size = sprite.size,
        });
    }

    system.health.draw(reg); // 绘制血条
    system.projectile.draw(reg); // 绘制投射物
    system.selection.draw(reg); // 绘制攻击范围和选择调试信息
}
