const ecs = @import("ecs");

const com = @import("../component.zig");

pub fn update(reg: *ecs.World, _: f32) void {
    var view = reg.query(.{ com.attack.Target, com.attack.Ready }).reverse();

    while (view.next()) |entity| {
        const target = reg.get(entity, com.attack.Target).?.v;
        if (reg.entities.get(target) == null) continue; // 目标无效

        // 被阻挡的远程敌人改用近身攻击动画。
        const ranged = reg.has(entity, com.attack.Ranged) and
            !reg.has(entity, com.motion.BlockBy);
        const attack: com.StateEnum = if (ranged) .ranged else .attack;
        reg.add(entity, com.animation.Play{
            .index = @backingInt(attack),
        });

        // 设置攻击锁定，不能进行移动
        reg.add(entity, com.attack.Lock{});
        // 设置攻击冷却
        reg.remove(entity, com.attack.Ready);
        reg.add(entity, com.Timer{
            .remaining = reg.get(entity, com.Stats).?.interval,
        });
    }
}
