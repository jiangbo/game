const ecs = @import("ecs");
const std = @import("std");

const com = @import("../component.zig");

pub fn update(reg: *ecs.World, _: f32) void {
    cleanInvalidTarget(reg);
    selectAttackTarget(reg);
}

///
/// 验证攻击目标是否死亡，是否在攻击范围内。
///
pub fn cleanInvalidTarget(reg: *ecs.World) void {
    var view = reg.query(.{ com.Stats, attack.Target }).reverse();

    while (view.next()) |entity| {
        if (reg.has(entity, attack.Lock)) continue; // 攻击锁定时不能切换目标

        const target = reg.get(entity, attack.Target).?.v;
        if (reg.get(entity, com.motion.BlockBy)) |blockBy| {
            if (reg.entities.get(blockBy.v) != null and
                std.meta.eql(target, blockBy.v))
            {
                continue; // 阻挡目标由阻挡系统维护，不按攻击范围清理。
            }
        }

        if (reg.entities.get(target) != null) { // 目标还存活
            const range = reg.get(entity, com.Stats).?.range + 20;
            const pos = reg.get(entity, com.Position).?;
            const targetPos = reg.get(reg.entities.get(target).?, com.Position).?;
            if (pos.sub(targetPos).length2() <= range * range) {
                continue; // 目标在攻击范围内
            }
        }
        std.log.debug("entity: {} clear target: {}", .{ entity, target.entity });
        reg.remove(entity, attack.Target);
    }
}

///
/// 选择一个最近的攻击目标
///
const attack = com.attack;
pub fn selectAttackTarget(reg: *ecs.World) void {
    var view = reg.query(.{ com.Stats, attack.Ready }).reverse();
    while (view.next()) |entity| {
        if (reg.has(entity, attack.Healer)) {
            selectHealTarget(reg, entity); // 选择治疗目标
            continue;
        }
        if (reg.has(entity, attack.Target)) continue; // 已经有目标了

        const pos = reg.get(entity, com.Position).?;
        const range = reg.get(entity, com.Stats).?.range + 20;
        const range2 = range * range;

        var closestTarget: ?ecs.Entity = null; // 找最近的敌方
        var closestLength2: f32 = std.math.floatMax(f32);

        const isEnemy = reg.has(entity, com.Enemy);
        var targetView = reg.query(.{ com.Position, com.Stats }).reverse();
        while (targetView.next()) |target| {
            if (isEnemy == reg.has(target, com.Enemy)) continue; // 同一边的

            const targetPos = reg.get(target, com.Position).?;
            const length2 = pos.sub(targetPos).length2();
            if (length2 <= range2 and length2 < closestLength2) {
                closestTarget = target;
                closestLength2 = length2;
            }
        }

        if (closestTarget) |target| {
            reg.add(entity, attack.Target{ .v = reg.entities.to(target).? });
            std.log.debug("entity: {} select attack target: {}", .{ entity, target });
        }
    }
}

fn selectHealTarget(reg: *ecs.World, entity: ecs.Entity) void {
    // 寻找自身范围内，血量最低的友方单位。
    const pos = reg.get(entity, com.Position).?;
    const range = reg.get(entity, com.Stats).?.range + 20;
    const range2 = range * range;

    var lowestTarget: ?ecs.Entity = null; // 找血量最低的友方
    var lowestHealthPercent: f32 = std.math.floatMax(f32);

    var view = reg.query(.{ com.Player, com.attack.Injured }).reverse(); // 找受伤的玩家
    while (view.next()) |target| {
        const targetPos = reg.get(target, com.Position).?;
        if (pos.sub(targetPos).length2() > range2) continue; // 不在治疗范围内

        const stats = reg.get(target, com.Stats).?;
        const healthPercent = stats.health / stats.maxHealth;
        if (healthPercent > lowestHealthPercent) continue;

        lowestHealthPercent = healthPercent;
        lowestTarget = target;
    }

    if (lowestTarget) |target| {
        reg.add(entity, attack.Target{ .v = reg.entities.to(target).? });
        std.log.debug("entity: {} select heal target: {}", .{ entity, target });
    } else {
        reg.remove(entity, attack.Target); // 移除之前的目标
    }
}
