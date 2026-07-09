const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");

const Action = component.actor.Action;
const Actor = component.actor.Actor;
const Facing = component.actor.Facing;
const Position = component.Position;
const Velocity = component.motion.Velocity;
const Wander = component.actor.Wander;
const Dialog = component.actor.Dialog;
const Life = component.actor.Life;
const Emit = component.sound.Emit;
const Voice = component.sound.Voice;

// 到达目标的距离阈值（平方），对应实际距离约 2.0
const arriveDistance2: f32 = 4.0;

pub fn update(world: *ecs.World, delta: f32) void {
    const talking = world.getIdentity(Dialog);
    var query = world.query(.{ Position, Velocity, Actor, Wander });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const velocity = query.getPtr(entity, Velocity);
        const actor = query.getPtr(entity, Actor);
        const wander = query.getPtr(entity, Wander);

        if (world.getPtr(entity, Voice)) |voice| {
            voice.remaining = @max(0, voice.remaining - delta);
        }

        // 只停止正在对话的 NPC，其他 NPC 继续正常漫游。
        if (talking == entity) {
            stop(actor, velocity, wander);
            continue;
        }

        // 睡觉和进食由生活系统控制，漫游只负责让出移动权。
        if (world.get(entity, Life)) |life| {
            if (life.state != .normal) {
                velocity.value = .zero;
                wander.moving = false;
                wander.stuckTimer = 0;
                continue;
            }
        }

        // 无效参数，直接停止
        if (wander.radius <= 0 or wander.speed <= 0) {
            stop(actor, velocity, wander);
            continue;
        }

        // 无效参数，直接停止
        if (wander.radius <= 0 or wander.speed <= 0) {
            stop(actor, velocity, wander);
            continue;
        }

        // --- 等待阶段：倒计时未结束则原地不动 ---
        if (!wander.moving) {
            wander.waitTimer -= delta;
            velocity.value = .zero;
            actor.action = .idle;
            if (wander.waitTimer > 0) continue;
            // 倒计时结束，随机选一个新目标
            chooseTarget(wander, position);
        }

        // --- 移动阶段：计算到目标的方向和距离 ---
        const toTarget = wander.target.sub(position);
        const distance2 = toTarget.length2();

        // 距离足够近，视为已到达
        if (distance2 <= arriveDistance2) {
            stop(actor, velocity, wander);
            tryEmitVoice(world, entity);
            wander.waitTimer = zhu.random.float(wander.minWait, wander.maxWait);
            continue;
        }

        // 设置速度方向和朝向
        const direction = toTarget.normalize();
        velocity.value = direction.scale(wander.speed);
        actor.action = Action.walk;
        actor.facing = facingFromDirection(direction);

        // --- 卡住检测：如果距离没有明显缩短，说明被卡住了 ---
        // 允许 1.0 的容差，避免浮点误差误判
        if (distance2 >= wander.lastDistance2 - 1.0) {
            wander.stuckTimer += delta;
            // 卡住时间超过阈值，放弃当前目标，重新等待
            if (wander.stuckTimer >= wander.stuckReset) {
                stop(actor, velocity, wander);
                wander.waitTimer = zhu.random.float(
                    wander.minWait,
                    wander.maxWait,
                );
                continue;
            }
        } else {
            wander.stuckTimer = 0;
        }
        wander.lastDistance2 = distance2;
    }
}

// 在 home 为圆心、wander.radius 为半径的圆内随机选一个点
fn chooseTarget(wander: *Wander, position: zhu.Vector2) void {
    const angle = zhu.random.float(0, std.math.pi * 2.0);
    const radius = zhu.random.float(0, wander.radius);
    const direction = zhu.Vector2.xy(@cos(angle), @sin(angle));
    // 目标 = 家 + 随机方向 * 随机距离
    wander.target = wander.home.add(direction.scale(radius));
    wander.moving = true;
    wander.stuckTimer = 0;
    // 记录初始距离，后续用于卡住检测
    wander.lastDistance2 = wander.target.sub(position).length2();
}

// 停止移动，清零速度，切换为待机状态
fn stop(actor: *Actor, velocity: *Velocity, wander: *Wander) void {
    velocity.value = .zero;
    actor.action = .idle;
    wander.moving = false;
}

fn tryEmitVoice(world: *ecs.World, entity: ecs.Entity) void {
    const voice = world.getPtr(entity, Voice) orelse return;
    if (voice.remaining > 0) return;
    if (zhu.random.float(0, 1) > voice.probability) return;

    world.add(entity, Emit{});
    voice.remaining = voice.coolDown;
}

// 根据移动方向决定朝向：取 x/y 分量绝对值较大的那个轴
fn facingFromDirection(direction: zhu.Vector2) Facing {
    if (@abs(direction.x) > @abs(direction.y)) {
        return if (direction.x < 0) .left else .right;
    }
    return if (direction.y < 0) .up else .down;
}

test "wander 会选择目标并写入速度" {
    zhu.random.init(1);

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{});
    world.add(entity, Actor{});
    world.add(entity, Wander{
        .home = .xy(10, 20),
        .radius = 32,
        .speed = 10,
    });

    update(&world, 0.1);

    const velocity = world.get(entity, Velocity).?;
    const actor = world.get(entity, Actor).?;
    const wander = world.get(entity, Wander).?;

    try std.testing.expect(wander.moving);
    try std.testing.expect(velocity.value.length2() > 0);
    try std.testing.expectEqual(Action.walk, actor.action);
}

test "wander 到达目标后进入等待" {
    zhu.random.init(1);

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{ .value = .xy(3, 0) });
    world.add(entity, Actor{ .action = .walk });
    world.add(entity, Wander{
        .home = .xy(10, 20),
        .radius = 32,
        .speed = 10,
        .target = .xy(11, 20),
        .moving = true,
    });

    update(&world, 0.1);

    const velocity = world.get(entity, Velocity).?;
    const actor = world.get(entity, Actor).?;
    const wander = world.get(entity, Wander).?;

    try std.testing.expect(!wander.moving);
    try std.testing.expect(wander.waitTimer > 0);
    try std.testing.expect(velocity.value.approxEqual(.zero));
    try std.testing.expectEqual(Action.idle, actor.action);
}

test "wander 到达目标时挂发声标记" {
    zhu.random.init(1);

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{ .value = .xy(3, 0) });
    world.add(entity, Actor{ .action = .walk });
    world.add(entity, Wander{
        .home = .xy(10, 20),
        .radius = 32,
        .speed = 10,
        .target = .xy(11, 20),
        .moving = true,
    });
    world.add(entity, Voice{ .probability = 1, .coolDown = 6 });

    update(&world, 0.1);

    try std.testing.expect(world.has(entity, Emit));
    try std.testing.expectEqual(6, world.get(entity, Voice).?.remaining);
}

test "wander 到达目标时遵守发声冷却" {
    zhu.random.init(1);

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{ .value = .xy(3, 0) });
    world.add(entity, Actor{ .action = .walk });
    world.add(entity, Wander{
        .home = .xy(10, 20),
        .radius = 32,
        .speed = 10,
        .target = .xy(11, 20),
        .moving = true,
    });
    world.add(entity, Voice{
        .probability = 1,
        .coolDown = 6,
        .remaining = 1,
    });

    update(&world, 0.1);

    try std.testing.expect(!world.has(entity, Emit));
    try std.testing.expectApproxEqAbs(
        @as(f32, 0.9),
        world.get(entity, Voice).?.remaining,
        0.001,
    );
}

test "对话中的 NPC 会停止漫游且不影响其它 NPC" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const talking = world.createEntity();
    world.add(talking, Position.xy(10, 20));
    world.add(talking, Velocity{ .value = .xy(3, 0) });
    world.add(talking, Actor{ .action = .walk });
    world.add(talking, Wander{
        .home = .xy(10, 20),
        .radius = 32,
        .speed = 10,
        .target = .xy(30, 20),
        .moving = true,
    });
    world.addIdentity(talking, Dialog);

    const other = world.createEntity();
    world.add(other, Position.xy(0, 0));
    world.add(other, Velocity{});
    world.add(other, Actor{});
    world.add(other, Wander{
        .home = .zero,
        .radius = 32,
        .speed = 10,
        .target = .xy(20, 0),
        .moving = true,
    });

    update(&world, 0.1);

    const talkingVelocity = world.get(talking, Velocity).?;
    const talkingActor = world.get(talking, Actor).?;
    const talkingWander = world.get(talking, Wander).?;
    const otherVelocity = world.get(other, Velocity).?;
    try std.testing.expect(talkingVelocity.value.approxEqual(.zero));
    try std.testing.expectEqual(Action.idle, talkingActor.action);
    try std.testing.expect(!talkingWander.moving);
    try std.testing.expect(otherVelocity.value.length2() > 0);
}

test "wander 对话停止不会挂发声标记" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{ .value = .xy(3, 0) });
    world.add(entity, Actor{ .action = .walk });
    world.add(entity, Wander{
        .home = .xy(10, 20),
        .radius = 32,
        .speed = 10,
        .target = .xy(30, 20),
        .moving = true,
    });
    world.add(entity, Voice{ .probability = 1, .coolDown = 6 });
    world.addIdentity(entity, Dialog);

    update(&world, 0.1);

    try std.testing.expect(!world.has(entity, Emit));
}
