const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");
const factory = @import("factory.zig");
const storage = @import("storage.zig");

const World = ecs.World;
const actor = component.actor;
const Position = component.Position;
const Trigger = component.map.Trigger;

pub fn spawn(world: *World, targetId: i32) void {
    const position = spawnPosition(world, targetId);
    factory.spawnPlayer(world, position);
    zhu.camera.directFollow(position);
}

pub fn capture(world: *World, mapId: component.map.Id) storage.Player {
    const entity = world.getIdentity(actor.Player).?;
    const position = world.get(entity, Position).?;
    const state = world.get(entity, actor.Actor) orelse actor.Actor{};

    return .{
        .map = mapId,
        .position = position,
        .facing = state.facing,
    };
}

pub fn restore(world: *World, data: storage.Player) void {
    const entity = world.getIdentity(actor.Player).?;
    const position = world.getPtr(entity, Position).?;
    const velocity = world.getPtr(entity, component.motion.Velocity).?;
    const target = world.getPtr(entity, component.ui.Target).?;
    const state = world.getPtr(entity, actor.Actor).?;

    position.* = data.position;
    velocity.value = .zero;
    target.active = false;
    state.action = .idle;
    state.facing = data.facing;
    world.remove(entity, actor.Busy);
    zhu.camera.directFollow(data.position);
}

fn spawnPosition(world: *World, targetId: i32) zhu.Vector2 {
    var query = world.query(.{Trigger});
    while (query.next()) |entity| {
        const trigger = query.get(entity, Trigger);
        if (trigger.selfId == targetId) return triggerPosition(trigger);
    }

    return .xy(311, 168);
}

fn triggerPosition(trigger: Trigger) zhu.Vector2 {
    const offset = 8;
    const center = trigger.rect.center();
    return switch (trigger.startOffset) {
        .left => .xy(trigger.rect.min.x - offset, center.y),
        .right => .xy(trigger.rect.max().x + offset, center.y),
        .top => .xy(center.x, trigger.rect.min.y - offset),
        .bottom => .xy(center.x, trigger.rect.max().y + offset),
        .none => center,
    };
}

test "触发器落点会按 start_offset 放到区域外侧" {
    const trigger = Trigger{
        .rect = .init(.xy(10, 20), .xy(30, 40)),
        .selfId = 1,
        .targetId = 1,
        .targetMap = .school,
        .startOffset = .bottom,
    };

    const position = triggerPosition(trigger);

    try std.testing.expectEqual(25, position.x);
    try std.testing.expectEqual(68, position.y);
}
