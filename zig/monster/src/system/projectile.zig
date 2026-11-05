const ecs = @import("ecs");
const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const spawn = @import("../spawn.zig");

pub fn update(reg: *ecs.World, delta: f32) void {
    spawn.projectile(reg, delta);

    // 更新所有投射物的飞行状态
    var view = reg.query(.{com.Projectile}).reverse();
    while (view.next()) |entity| {
        const projectile = reg.getPtr(entity, com.Projectile).?;
        projectile.time += delta;

        // 飞行时间是否大于等于总时间
        if (projectile.time >= projectile.totalTime) {
            hitTarget(reg, projectile.*);
            reg.destroyEntity(entity);
            continue;
        }

        // 计算移动的位置
        var percent = projectile.time / projectile.totalTime;
        percent = std.math.clamp(percent, 0.0, 1.0);
        var pos = projectile.start.mix(projectile.end, percent);

        const arc = @sin(percent * std.math.pi) * projectile.arc;
        pos = pos.addY(-arc).add(projectile.offset);
        reg.add(entity, pos);

        // 处理旋转角度
        const direction = pos.sub(projectile.previous);
        projectile.rotation = std.math.atan2(direction.y, direction.x);
        projectile.previous = pos;
    }
}

fn hitTarget(reg: *ecs.World, projectile: com.Projectile) void {
    const target = reg.entities.get(projectile.target) orelse return;
    const stats = reg.getPtr(target, com.Stats) orelse return;

    if (projectile.hitSound) |path| zhu.audio.playSound(path);

    const damage = projectile.damage - stats.defense;
    stats.health -= @max(damage, projectile.damage / 10);

    reg.add(target, com.attack.Injured{});
    if (stats.health <= 0) {
        reg.add(target, com.Dead{});
    }
}

pub fn draw(reg: *ecs.World) void {
    var view = reg.query(.{com.Projectile}).reverse();

    while (view.next()) |entity| {
        const projectile = reg.getPtr(entity, com.Projectile).?;
        const image = reg.get(entity, zhu.graphics.Image).?;
        const position = reg.get(entity, com.Position).?;
        zhu.batch.drawImage(image, position, .{
            .radian = projectile.rotation,
        });
    }
}
