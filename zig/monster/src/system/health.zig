const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const spawn = @import("../spawn.zig");

pub fn update(reg: *zhu.ecs.Registry, _: f32) void {
    var view = reg.view(.{ com.attack.Hit, com.attack.Target });
    while (view.next()) |entity| {
        const target = view.get(entity, com.attack.Target).v;

        if (view.tryGet(entity, com.audio.Hit)) |hitSound| {
            zhu.audio.playSound(hitSound.path); // 播放命中声音
        }

        const attack = view.getPtr(entity, com.Stats).attack;
        const stats = reg.tryGetPtr(target, com.Stats) orelse continue;

        if (attack < 0) { // 治疗
            stats.health -= attack;
            if (stats.health >= stats.maxHealth) {
                stats.health = stats.maxHealth;
                reg.remove(target, com.attack.Injured); // 移除受伤标签
            }
            if (reg.tryGet(target, com.Position)) |position| {
                const effect = spawn.effect(reg, .heal);
                reg.add(effect, position);
                reg.add(effect, com.DeadOnFinish{});
            }
            const msg = "entity: {} heal target: {}, health: {}";
            std.log.debug(msg, .{ entity, target.index, stats.health });
            continue;
        }

        // 伤害
        const damage = attack - stats.defense;
        stats.health -= @max(damage, attack / 10);
        const msg = "entity: {} attack target: {}, damage: {}, health: {}";
        std.log.debug(msg, .{ entity, target.index, damage, stats.health });

        view.add(target.index, com.attack.Injured{}); // 目标受伤了
        if (stats.health <= 0) {
            view.add(target.index, com.Dead{}); // 目标死了
            std.log.debug("entity: {} killed target: {}", .{ entity, target.index });
        }
    }

    reg.clear(com.attack.Hit);
}

pub fn draw(reg: *zhu.ecs.Registry) void {
    const size: zhu.Vector2 = .xy(40, 10);

    var view = reg.view(.{ com.attack.Injured, com.Stats });
    while (view.next()) |entity| {
        const stats = view.getPtr(entity, com.Stats);
        const percent = stats.health / stats.maxHealth;

        var pos = view.get(entity, com.Position);
        pos = pos.addXY(-size.x / 2, size.y);

        var color = zhu.graphics.Color.red;
        if (percent > 0.7) color = .green //
        else if (percent > 0.3) color = .yellow;

        var rect = zhu.math.Rect{ .min = pos, .size = size };
        zhu.batch.drawRectBorder(rect, 2, color);
        rect.size.x *= @max(percent, 0);
        zhu.batch.drawRect(rect, .{ .color = color });
    }
}
