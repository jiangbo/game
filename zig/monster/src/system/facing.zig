const ecs = @import("ecs");

const com = @import("../component.zig");

pub fn update(reg: *ecs.World, _: f32) void {
    facingTarget(reg);
    facingMove(reg);
}

///
/// 朝向目标
///
fn facingTarget(reg: *ecs.World) void {
    var view = reg.query(.{ com.attack.Target, com.Sprite }).reverse();

    while (view.next()) |entity| {
        const sprite = reg.getPtr(entity, com.Sprite).?;
        const pos = reg.get(entity, com.Position).?;
        const target = reg.get(entity, com.attack.Target).?.v;

        if (reg.entities.get(target) == null) continue; // 目标无效了

        const targetPos = reg.get(reg.entities.get(target).?, com.Position).?;
        const imageFaceLeft = reg.has(entity, com.motion.FaceLeft);

        // 想朝右，图片朝左，翻转
        if (pos.x < targetPos.x) sprite.flip = imageFaceLeft
            // 想朝左，图片朝左，不翻转
        else if (pos.x > targetPos.x) sprite.flip = !imageFaceLeft;
    }
}

///
/// 朝向移动方向
///
fn facingMove(reg: *ecs.World) void {
    var view = reg.query(.{ com.motion.Velocity, com.Sprite }).reverse();

    while (view.next()) |entity| {
        if (reg.has(entity, com.motion.BlockBy)) continue; // 被阻挡的不处理
        if (reg.has(entity, com.attack.Lock)) continue; // 攻击锁定的不处理

        const sprite = reg.getPtr(entity, com.Sprite).?;
        const velocity = reg.get(entity, com.motion.Velocity).?;
        const imageFaceLeft = reg.has(entity, com.motion.FaceLeft);

        // 想朝右，图片朝左，翻转
        sprite.flip = if (velocity.v.x > 0) imageFaceLeft //
            else !imageFaceLeft; // 想朝左，图片朝左，不翻转
    }
}
