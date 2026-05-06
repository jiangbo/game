const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const map = @import("../map.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    followPath(reg);
    move(reg, delta);
}

fn followPath(registry: *zhu.ecs.Registry) void {
    var view = registry.view(.{ com.Enemy, com.motion.Velocity });
    while (view.next()) |entity| {
        if (view.has(entity, com.attack.Lock)) continue; // 攻击锁定的不处理

        if (view.tryGet(entity, com.motion.BlockBy)) |blockBy| {
            if (registry.validEntity(blockBy.v)) continue;
            view.remove(entity, com.motion.BlockBy);
            view.add(entity, com.animation.Play{
                .index = @intFromEnum(com.StateEnum.walk),
                .loop = true,
            });
        }

        // 当前位置和目标位置是否足够靠近
        const enemy = view.getPtr(entity, com.Enemy);
        const pos = view.get(entity, com.Position);
        if (enemy.target.point.sub(pos).length2() > 25) continue;

        // 到达目标位置，转向，即更新速度
        var nextPathId = enemy.target.next;
        if (enemy.target.next2 != 0) {
            // 随机选择下一条路径
            if (zhu.randomBool()) nextPathId = enemy.target.next2;
        }

        if (nextPathId == 0) { // 到达终点，销毁实体
            registry.addEvent(view.toEntity(entity));
            continue;
        }
        enemy.target = map.paths.get(nextPathId).?;
        const velocity = view.getPtr(entity, com.motion.Velocity);
        const direction = enemy.target.point.sub(pos).normalize();
        velocity.v = direction.scale(enemy.speed);
    }
}

fn move(registry: *zhu.ecs.Registry, delta: f32) void {
    var view = registry.view(.{com.motion.Velocity});
    while (view.next()) |entity| {
        if (view.has(entity, com.motion.BlockBy)) continue; // 被阻挡的不处理
        if (view.has(entity, com.attack.Lock)) continue; // 攻击锁定的不处理

        // 先移动
        const position = view.getPtr(entity, com.Position);
        const velocity = view.get(entity, com.motion.Velocity);
        position.* = position.*.add(velocity.v.scale(delta));

        // 再检查是否被阻挡
        var blockView = registry.view(.{com.motion.Blocker});
        while (blockView.next()) |blocker| {
            const pos = blockView.get(blocker, com.Position);
            if (pos.sub(position.*).length2() > 40 * 40) continue;

            const block = blockView.getPtr(blocker, com.motion.Blocker);
            if (block.current < block.max) {
                const target = blockView.toEntity(blocker);
                view.add(entity, com.motion.BlockBy{ .v = target });
                view.add(entity, com.attack.Target{ .v = target });
                block.current += 1;
                break;
            }
        }
    }
}
