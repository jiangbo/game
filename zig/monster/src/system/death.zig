const ecs = @import("ecs");
const std = @import("std");

const com = @import("../component.zig");
const spawn = @import("../spawn.zig");
const skill = @import("skill.zig");
const ctx = @import("../context.zig");

/// 处理死亡实体
pub fn update(reg: *ecs.World, _: f32) void {
    var deadView = reg.query(.{com.Dead}).reverse();
    while (deadView.next()) |entity| {
        std.log.info("death entity: {}", .{entity});
        defer destroy(reg, entity);

        if (reg.has(entity, com.Player)) {
            spawn.releasePlace(entity);
            continue;
        }

        // 死亡实体被阻挡了，释放阻挡锁定
        if (reg.get(entity, com.motion.BlockBy)) |blockBy| {
            if (reg.entities.get(blockBy.v)) |target| {
                if (reg.getPtr(target, com.motion.Blocker)) |blocker| {
                    blocker.current -|= 1;
                }
            }
        }

        if (reg.has(entity, com.EnemyEnum)) {
            ctx.enemyKilledCount += 1;
            spawn.deadEnemy(reg, entity);
        }
    }
}

/// 在编号可复用前清除界面引用和拥有的技能特效。
pub fn destroy(reg: *ecs.World, entity: ecs.Entity) void {
    if (ctx.hoveredEntity == entity) ctx.hoveredEntity = null;
    if (ctx.selectedEntity == entity) ctx.selectedEntity = null;
    skill.removeDisplay(reg, entity);
    reg.destroyEntity(entity);
}
