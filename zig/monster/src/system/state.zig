const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    _ = delta;

    var view = reg.view(.{com.animation.Finished});

    while (view.next()) |entity| {
        if (view.has(entity, com.DeadOnFinish)) {
            view.add(entity, com.Dead{});
            continue;
        }

        var state = com.StateEnum.idle;
        if (view.has(entity, com.Player)) {
            if (view.tryGet(entity, com.skill.Skill)) |skill| {
                if (skill.id == .shield and view.has(entity, com.skill.Active)) {
                    state = .walk;
                }
            }
        }
        // 敌人需要区分是否被阻挡
        var blocked = false;
        if (view.tryGet(entity, com.motion.BlockBy)) |blockBy| {
            if (reg.validEntity(blockBy.v)) blocked = true else {
                view.remove(entity, com.motion.BlockBy);
            }
        }
        if (view.has(entity, com.Enemy) and !blocked) state = .walk;

        view.add(entity, com.animation.Play{
            .index = @intFromEnum(state),
            .loop = true,
        });

        // 移除攻击锁定
        view.remove(entity, com.attack.Lock);
    }

    reg.clear(com.animation.Finished);
}
