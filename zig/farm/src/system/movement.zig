const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const map = @import("../map.zig");

const Position = component.Position;
const Player = component.actor.Player;
const Velocity = component.motion.Velocity;
const Shape = component.motion.Shape;
const Blocking = component.motion.Blocking;
const World = ecs.World;
const Entity = ecs.Entity;

pub fn update(world: *World, delta: f32) void {
    var query = world.query(.{ Position, Velocity });
    while (query.next()) |entity| {
        const velocity = query.get(entity, Velocity);
        if (velocity.value.approxEqual(.zero)) continue;

        const pos = query.getPtr(entity, Position);
        const offset = velocity.value.scale(delta);

        // 轴分离碰撞解析：先尝试 X 轴移动，再尝试 Y 轴移动。
        // 碰撞时只回退受阻轴，这样可以沿墙滑动而不会卡死。
        const posX = pos.addX(offset.x);
        if (map.canMove(world, entity, posX)) pos.* = posX;

        // Y 轴基于 X 轴已接受的位置继续检测，保持斜向移动和滑动。
        const posY = pos.addY(offset.y);
        if (map.canMove(world, entity, posY)) pos.* = posY;
    }

    followPlayer(world, delta);
}

fn followPlayer(world: *World, delta: f32) void {
    const entity = world.getIdentity(Player) orelse return;
    const position = world.get(entity, Position).?;

    const speed: f32 = 9;
    zhu.camera.smoothFollow(position, speed * delta);
    zhu.camera.roundPosition();
}

test "移动系统会按速度更新位置" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, Velocity{ .value = .xy(3, -4) });
    world.add(entity, Shape{ .rect = .init(.zero, .xy(1, 1)) });

    update(&world, 0.5);

    const position = world.get(entity, Position).?;
    try std.testing.expect(position.approxEqual(.xy(11.5, 18)));
}

const testMap = zhu.extend.tiled.Map{
    .grid = .{ .width = 30, .height = 17, .cell = 16 },
    .layers = &.{},
};

fn addMover(world: *World, position: zhu.Vector2, velocity: zhu.Vector2) Entity {
    const entity = world.createEntity();
    world.add(entity, position);
    world.add(entity, Velocity{ .value = velocity });
    world.add(entity, Shape{ .rect = .init(.zero, .xy(10, 10)) });
    world.add(entity, Blocking{});
    return entity;
}

fn addBlocker(world: *World, position: zhu.Vector2, blocking: bool) Entity {
    const entity = world.createEntity();
    world.add(entity, position);
    world.add(entity, Shape{ .rect = .init(.zero, .xy(10, 10)) });
    if (blocking) world.add(entity, Blocking{});
    return entity;
}

test "动态阻挡会忽略自己" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const entity = addMover(&world, .xy(0, 0), .xy(10, 0));

    update(&world, 1);

    try std.testing.expectEqual(10, world.get(entity, Position).?.x);
}

test "带 Blocking 的 Shape 会挡住移动" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const mover = addMover(&world, .xy(0, 0), .xy(10, 0));
    _ = addBlocker(&world, .xy(10, 0), true);

    update(&world, 1);

    try std.testing.expectEqual(0, world.get(mover, Position).?.x);
}

test "没有 Blocking 的 Shape 不会挡住移动" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const mover = addMover(&world, .xy(0, 0), .xy(10, 0));
    _ = addBlocker(&world, .xy(10, 0), false);

    update(&world, 1);

    try std.testing.expectEqual(10, world.get(mover, Position).?.x);
}

test "动态阻挡只回退受阻轴" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const mover = addMover(&world, .xy(0, 0), .xy(10, 5));
    _ = addBlocker(&world, .xy(10, 0), true);

    update(&world, 1);

    const position = world.get(mover, Position).?;
    try std.testing.expectEqual(0, position.x);
    try std.testing.expectEqual(5, position.y);
}
