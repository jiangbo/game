const ecs = @import("ecs");
const zhu = @import("zhu");

const com = @import("../component.zig");
const map = @import("../map.zig");

pub fn update(reg: *ecs.World, delta: f32) void {
    followPath(reg);
    move(reg, delta);
}

fn followPath(registry: *ecs.World) void {
    var view = registry.query(.{ com.Enemy, com.motion.Velocity }).reverse();
    while (view.next()) |entity| {
        if (registry.has(entity, com.attack.Lock)) continue; // 攻击锁定的不处理

        if (registry.get(entity, com.motion.BlockBy)) |blockBy| {
            if (registry.entities.get(blockBy.v) != null) continue;
            registry.remove(entity, com.motion.BlockBy);
            registry.add(entity, com.animation.Play{
                .index = @backingInt(com.StateEnum.walk),
                .loop = true,
            });
        }

        // 当前位置和目标位置是否足够靠近
        const enemy = registry.getPtr(entity, com.Enemy).?;
        const pos = registry.get(entity, com.Position).?;
        if (enemy.target.point.sub(pos).length2() > 25) continue;

        // 到达目标位置，转向，即更新速度
        var nextPathId = enemy.target.next;
        if (enemy.target.next2 != 0) {
            // 随机选择下一条路径
            if (zhu.random.boolean()) nextPathId = enemy.target.next2;
        }

        if (nextPathId == 0) { // 到达终点，销毁实体
            registry.add(entity, com.Arrived{});
            continue;
        }
        enemy.target = map.paths.get(nextPathId).?;
        const velocity = registry.getPtr(entity, com.motion.Velocity).?;
        const direction = enemy.target.point.sub(pos).normalize();
        velocity.v = direction.scale(enemy.speed);
    }
}

fn move(registry: *ecs.World, delta: f32) void {
    var view = registry.queryNot(.{com.motion.Velocity}, .{com.Arrived}).reverse();
    while (view.next()) |entity| {
        if (registry.has(entity, com.motion.BlockBy)) continue; // 被阻挡的不处理
        if (registry.has(entity, com.attack.Lock)) continue; // 攻击锁定的不处理

        // 先移动
        const position = registry.getPtr(entity, com.Position).?;
        const velocity = registry.get(entity, com.motion.Velocity).?;
        position.* = position.*.add(velocity.v.scale(delta));

        // 再检查是否被阻挡
        var blockView = registry.query(.{com.motion.Blocker}).reverse();
        while (blockView.next()) |blocker| {
            const pos = registry.get(blocker, com.Position).?;
            if (pos.sub(position.*).length2() > 40 * 40) continue;

            const block = registry.getPtr(blocker, com.motion.Blocker).?;
            if (block.current < block.max) {
                const target = registry.entities.to(blocker).?;
                registry.add(entity, com.motion.BlockBy{ .v = target });
                registry.add(entity, com.attack.Target{ .v = target });
                block.current += 1;
                break;
            }
        }
    }
}
