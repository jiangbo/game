const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const Clock = @import("../resource/Clock.zig");

const Actor = component.actor.Actor;
const Life = component.actor.Life;
const Velocity = component.motion.Velocity;
const Wander = component.actor.Wander;

pub fn update(world: *ecs.World, delta: f32) void {
    const clock = world.get(world.entity, Clock).?;
    if (clock.period == .night) {
        return updateSleep(world);
    }

    updateDay(world, delta);
}

fn updateSleep(world: *ecs.World) void {
    var query = world.query(.{ Actor, Life });
    while (query.next()) |entity| {
        const actor = query.getPtr(entity, Actor);
        const life = query.getPtr(entity, Life);

        // 夜晚睡觉优先于进食，直接停住并跳过后续生活逻辑。
        life.state = .sleep;
        life.timer = 0;
        faceFront(actor);
        actor.action = .sleep;
        stopMoving(world, entity);
    }
}

fn updateDay(world: *ecs.World, delta: f32) void {
    var query = world.query(.{ Actor, Life });
    while (query.next()) |entity| {
        const actor = query.getPtr(entity, Actor);
        const life = query.getPtr(entity, Life);

        // 离开夜晚后恢复普通状态，并重新安排下一次进食。
        if (life.state == .sleep) {
            enterNormal(life);
            actor.action = .idle;
        }

        switch (life.state) {
            .normal => {
                // 普通状态下等待进食冷却结束。
                life.timer -= delta;
                if (life.timer > 0) continue;

                // 冷却结束后进入进食，进食时长也做轻微随机。
                life.state = .eat;
                const duration = Life.eatDuration;
                life.timer = zhu.random.float(duration * 0.5, duration);
                faceFront(actor);
                actor.action = .eat;
                stopMoving(world, entity);
            },
            .eat => {
                // 进食期间持续保持动作并停止移动。
                life.timer -= delta;
                faceFront(actor);
                actor.action = .eat;
                stopMoving(world, entity);
                if (life.timer > 0) continue;

                // 进食结束后回到普通状态，等待下一次进食。
                enterNormal(life);
                actor.action = .idle;
            },
            .sleep => unreachable,
        }
    }
}

fn faceFront(actor: *Actor) void {
    // 动物睡觉和进食没有背面帧，朝上时使用正面帧替代。
    if (actor.facing == .up) actor.facing = .down;
}

fn enterNormal(life: *Life) void {
    life.state = .normal;
    const interval = Life.eatInterval;
    // 下一次进食等待时间随机化，避免多个角色节奏完全同步。
    life.timer = zhu.random.float(interval * 0.5, interval);
}

fn stopMoving(world: *ecs.World, entity: ecs.Entity) void {
    if (world.getPtr(entity, Velocity)) |velocity| {
        velocity.value = .zero;
    }
    if (world.getPtr(entity, Wander)) |wander| {
        wander.moving = false;
        wander.waitTimer = 0;
        wander.stuckTimer = 0;
    }
}

test "夜晚有生活状态的角色会睡觉并停止移动" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    world.entity = world.createEntity();
    world.add(world.entity, Clock{ .period = .night });

    const entity = world.createEntity();
    world.add(entity, Actor{ .action = .walk });
    world.add(entity, Life{ .timer = 1 });
    world.add(entity, Velocity{ .value = .xy(3, 0) });
    world.add(entity, Wander{ .moving = true, .waitTimer = 1 });

    update(&world, 0.1);

    const actor = world.get(entity, Actor).?;
    const life = world.get(entity, Life).?;
    const velocity = world.get(entity, Velocity).?;
    const wander = world.get(entity, Wander).?;
    try std.testing.expectEqual(.sleep, life.state);
    try std.testing.expectEqual(.sleep, actor.action);
    try std.testing.expect(velocity.value.approxEqual(.zero));
    try std.testing.expect(!wander.moving);
}

test "天亮后退出睡眠并重置进食计时" {
    zhu.random.init(1);

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    world.entity = world.createEntity();
    world.add(world.entity, Clock{ .period = .day });

    const entity = world.createEntity();
    world.add(entity, Actor{ .action = .sleep });
    world.add(entity, Life{
        .state = .sleep,
        .timer = 0,
    });

    update(&world, 0.1);

    const actor = world.get(entity, Actor).?;
    const life = world.get(entity, Life).?;
    try std.testing.expectEqual(.normal, life.state);
    try std.testing.expectEqual(.idle, actor.action);
    try std.testing.expect(life.timer >= 4);
    try std.testing.expect(life.timer <= 8);
}

test "进食冷却结束后进入进食状态" {
    zhu.random.init(1);

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    world.entity = world.createEntity();
    world.add(world.entity, Clock{ .period = .day });

    const entity = world.createEntity();
    world.add(entity, Actor{});
    world.add(entity, Life{
        .timer = 0.05,
    });
    world.add(entity, Velocity{ .value = .xy(3, 0) });
    world.add(entity, Wander{ .moving = true });

    update(&world, 0.1);

    const actor = world.get(entity, Actor).?;
    const life = world.get(entity, Life).?;
    const velocity = world.get(entity, Velocity).?;
    try std.testing.expectEqual(.eat, life.state);
    try std.testing.expectEqual(.eat, actor.action);
    try std.testing.expect(life.timer >= 1);
    try std.testing.expect(life.timer <= 2);
    try std.testing.expect(velocity.value.approxEqual(.zero));
}

test "进食结束后回到普通状态" {
    zhu.random.init(1);

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    world.entity = world.createEntity();
    world.add(world.entity, Clock{ .period = .day });

    const entity = world.createEntity();
    world.add(entity, Actor{ .action = .eat });
    world.add(entity, Life{
        .state = .eat,
        .timer = 0.05,
    });

    update(&world, 0.1);

    const actor = world.get(entity, Actor).?;
    const life = world.get(entity, Life).?;
    try std.testing.expectEqual(.normal, life.state);
    try std.testing.expectEqual(.idle, actor.action);
    try std.testing.expect(life.timer >= 4);
    try std.testing.expect(life.timer <= 8);
}

test "睡觉优先于进食" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    world.entity = world.createEntity();
    world.add(world.entity, Clock{ .period = .night });

    const entity = world.createEntity();
    world.add(entity, Actor{ .action = .eat });
    world.add(entity, Life{
        .state = .eat,
        .timer = 1,
    });

    update(&world, 0.1);

    const actor = world.get(entity, Actor).?;
    const life = world.get(entity, Life).?;
    try std.testing.expectEqual(.sleep, life.state);
    try std.testing.expectEqual(.sleep, actor.action);
}

test "睡觉和进食没有背面帧时改用正面方向" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    world.entity = world.createEntity();
    world.add(world.entity, Clock{ .period = .night });

    const sleepEntity = world.createEntity();
    world.add(sleepEntity, Actor{ .facing = .up });
    world.add(sleepEntity, Life{});

    update(&world, 0.1);

    try std.testing.expectEqual(.down, world.get(sleepEntity, Actor).?.facing);

    zhu.random.init(1);
    const eatEntity = world.createEntity();
    world.add(eatEntity, Actor{ .facing = .up });
    world.add(eatEntity, Life{ .timer = 0 });

    world.getPtr(world.entity, Clock).?.period = .day;
    update(&world, 0.1);

    try std.testing.expectEqual(.down, world.get(eatEntity, Actor).?.facing);
}
