const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const Trigger = component.map.Trigger;
const Transition = component.map.Transition;

pub fn update(world: *ecs.World) void {
    const player = world.getIdentity(component.actor.Player).?;
    const position = world.get(player, component.Position).?;

    var query = world.query(.{Trigger});
    while (query.next()) |entity| {
        const trigger = query.get(entity, Trigger);
        if (trigger.rect.contains(position)) {
            world.add(player, Transition{
                .target = trigger.targetMap,
                .targetId = trigger.targetId,
            });
            return;
        }
    }
}
