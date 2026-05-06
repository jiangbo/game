const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");
const spawn = @import("../spawn.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    spawn.projectile(reg, delta);

    // 更新所有投射物的飞行状态
    var view = reg.reverseView(.{com.Projectile});
    while (view.next()) |entity| {
        const projectile = view.getPtr(entity, com.Projectile);
        projectile.time += delta;

        // 飞行时间是否大于等于总时间
        if (projectile.time >= projectile.totalTime) {
            hitTarget(reg, projectile.*);
            view.destroy(entity);
            continue;
        }

        // 计算移动的位置
        var percent = projectile.time / projectile.totalTime;
        percent = std.math.clamp(percent, 0.0, 1.0);
        var pos = projectile.start.mix(projectile.end, percent);

        const arc = @sin(percent * std.math.pi) * projectile.arc;
        pos = pos.addY(-arc).add(projectile.offset);
        view.add(entity, pos);

        // 处理旋转角度
        const direction = pos.sub(projectile.previous);
        projectile.rotation = std.math.atan2(direction.y, direction.x);
        projectile.previous = pos;
    }
}

fn hitTarget(reg: *zhu.ecs.Registry, projectile: com.Projectile) void {
    const stats = reg.tryGetPtr(projectile.target, com.Stats) orelse return;

    if (reg.validEntity(projectile.owner)) {
        if (reg.tryGet(projectile.owner, com.audio.Hit)) |hitSound| {
            zhu.audio.playSound(hitSound.path);
        }
    }

    const damage = projectile.damage - stats.defense;
    stats.health -= @max(damage, projectile.damage / 10);

    reg.add(projectile.target, com.attack.Injured{});
    if (stats.health <= 0) {
        reg.add(projectile.target, com.Dead{});
    }
}

pub fn draw(reg: *zhu.ecs.Registry) void {
    var view = reg.view(.{com.Projectile});

    while (view.next()) |entity| {
        const projectile = view.getPtr(entity, com.Projectile);
        const image = view.get(entity, zhu.graphics.Image);
        const position = view.get(entity, com.Position);
        zhu.batch.drawImage(image, position, .{
            .radian = projectile.rotation,
        });
    }
}
