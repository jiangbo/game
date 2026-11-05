const ecs = @import("ecs");
const com = @import("../component.zig");

pub fn update(world: *ecs.World, delta: f32) void {
    var query = world.query(.{com.Timer}).reverse();
    while (query.next()) |entity| {
        const timer = world.getPtr(entity, com.Timer).?;
        timer.remaining -= delta;
        if (timer.remaining > 0) continue;
        world.add(entity, com.attack.Ready{});
        world.remove(entity, com.Timer);
    }
}
