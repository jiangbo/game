const ecs = @import("ecs");

const com = @import("../component.zig");

pub fn update(reg: *ecs.World, delta: f32) void {
    _ = delta;

    var view = reg.query(.{com.animation.Finished}).reverse();

    while (view.next()) |entity| {
        if (reg.has(entity, com.DeadOnFinish)) {
            reg.add(entity, com.Dead{});
            continue;
        }

        var state = com.StateEnum.idle;
        if (reg.has(entity, com.Player)) {
            if (reg.get(entity, com.skill.Skill)) |skill| {
                if (skill.id == .shield and reg.has(entity, com.skill.Active)) {
                    state = .walk;
                }
            }
        }
        // 敌人需要区分是否被阻挡
        var blocked = false;
        if (reg.get(entity, com.motion.BlockBy)) |blockBy| {
            if (reg.entities.get(blockBy.v) != null) blocked = true else {
                reg.remove(entity, com.motion.BlockBy);
            }
        }
        if (reg.has(entity, com.Enemy) and !blocked) state = .walk;

        reg.add(entity, com.animation.Play{
            .index = state,
            .loop = true,
        });

        // 移除攻击锁定
        reg.remove(entity, com.attack.Lock);
    }

    reg.clear(com.animation.Finished);
}
