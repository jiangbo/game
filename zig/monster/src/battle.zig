const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;
const com = @import("component.zig");

///
///  删除已经结束的攻击计时器。
///
pub fn cleanAttackTimerIfDone(reg: *ecs.Registry, delta: f32) void {
    var view = reg.viewOption(.{com.AttackTimer}, .{
        .reverse = true, // 倒序遍历，因为可能会移除组件
    });

    while (view.next()) |entity| {
        const timer = view.getPtr(entity, com.AttackTimer);
        if (timer.v.isFinishedOnceUpdate(delta)) {
            view.remove(entity, com.AttackTimer);
        }
    }
}

///
/// 验证攻击目标是否死亡，是否在攻击范围内。
///
pub fn cleanInvalidTarget(reg: *ecs.Registry) void {
    var view = reg.viewOption(.{ com.AttackRange, com.Target }, .{
        .reverse = true, // 倒序遍历，因为遍历 Target 的时候可能会移除它
    });

    while (view.next()) |entity| {
        const target = view.get(entity, com.Target).v;
        if (reg.validEntity(target)) { // 目标还存活
            const range = view.get(entity, com.AttackRange).v + 20; // 目标的中心
            const pos = view.get(entity, com.Position);
            const targetPos = reg.get(target, com.Position);
            if (pos.sub(targetPos).length2() <= range * range) {
                continue; // 目标在攻击范围内
            }
        }
        std.log.debug("entity: {} clean target: {}", .{ entity, target });
        view.remove(entity, com.Target);
    }
}

///
/// 攻击
///
pub fn attack(reg: *ecs.Registry) void {
    var view = reg.view(.{ com.Position, com.AttackRange });
    while (view.next()) |entity| {
        if (view.has(entity, com.AttackTimer)) continue; // 攻击冷却中

        if (view.tryGet(entity, com.Target)) |target| {
            reg.addEvent(com.AttackEvent{ // 已经有目标了，直接攻击
                .attacker = view.toEntity(entity),
                .target = target.v,
            });
            continue;
        }

        const pos = view.get(entity, com.Position);
        const range = view.get(entity, com.AttackRange).v + 20; // 目标的中心
        const range2 = range * range;

        var closestTarget: ?zhu.ecs.Entity.Index = null; // 找最近的敌方
        var closestLength2: f32 = std.math.floatMax(f32);

        const isEnemy = view.has(entity, com.Enemy);
        var targetView = reg.view(.{com.Position});
        while (targetView.next()) |target| {
            if (isEnemy == view.has(target, com.Enemy)) continue; // 同一边的

            const targetPos = targetView.get(target, com.Position);
            const length2 = pos.sub(targetPos).length2();
            if (length2 <= range2 and length2 < closestLength2) {
                closestTarget = target;
                closestLength2 = length2;
            }
        }

        if (closestTarget) |target| {
            view.add(entity, com.Target{ .v = view.toEntity(target) });
            std.log.debug("entity: {} attack: {}", .{ entity, target });
            reg.addEvent(com.AttackEvent{ // 找到了目标，攻击
                .attacker = view.toEntity(entity),
                .target = view.toEntity(target),
            });
        }
    }
}
