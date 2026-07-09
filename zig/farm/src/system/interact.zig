const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const input = @import("../input.zig");
const map = @import("../map.zig");

const World = ecs.World;
const Entity = ecs.Entity;
const Position = component.Position;
const Player = component.actor.Player;
const Interact = component.actor.Interact;
const Dialog = component.actor.Dialog;
const Shape = component.motion.Shape;
const Hit = component.map.Hit;

pub fn update(world: *World) void {
    world.removeIdentity(Interact);

    // 对话中按键由 dialog 系统消费，不再重新寻找目标。
    if (world.getIdentity(Dialog) != null) return;
    if (!input.pressed(.interact)) return;

    const player = world.getIdentity(Player).?;
    const playerPos = targetCenter(world, player);

    markFacingHits(world);
    defer world.clear(Hit);

    var bestEntity: ?Entity = null;
    var bestDist2: f32 = std.math.inf(f32);

    var query = world.query(.{ Hit, Interact, Position });
    while (query.next()) |entity| {
        const pos = targetCenter(world, entity);
        const dist2 = playerPos.sub(pos).length2();
        if (dist2 < bestDist2) {
            bestDist2 = dist2;
            bestEntity = entity;
        }
    }

    const target = bestEntity orelse return;
    world.addIdentity(target, Interact);
}

/// 标记玩家正前方探测框范围内所有实体的 Hit 组件。
fn markFacingHits(world: *World) void {
    const player = world.getIdentity(Player).?;
    const pos = world.get(player, Position).?;
    const facing = world.get(player, component.actor.Actor).?.facing;

    const ts = map.grid.cellSize().x; // 当前地图格子大小
    const probeSize = ts + 4 * 2;
    const half = probeSize / 2;
    const origin = pos.add(switch (facing) {
        .down => zhu.Vector2.xy(-half, ts - half),
        .up => zhu.Vector2.xy(-half, -ts - half),
        .right => zhu.Vector2.xy(ts - half, -half),
        .left => zhu.Vector2.xy(-ts - half, -half),
    });
    const rect = zhu.Rect.init(origin, .square(probeSize));

    var query = world.query(.{ Position, Shape });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const body = query.get(entity, Shape);
        if (body.move(position).intersect(rect)) {
            query.add(world, entity, Hit{});
        }
    }
}

fn targetCenter(world: *World, entity: Entity) Position {
    const position = world.get(entity, Position).?;
    const shape = world.get(entity, Shape).?;
    return shape.move(position).toRect().center();
}

fn addTestPlayer(world: *World, position: Position) Entity {
    const player = world.createIdentity(Player);
    world.add(player, position);
    world.add(player, component.actor.Actor{ .facing = .down });
    world.add(player, Shape{ .circle = .init(.xy(0, -5), 5) });
    return player;
}

fn addTestNpc(world: *World, position: Position) Entity {
    const npc = world.createEntity();
    world.add(npc, position);
    world.add(npc, Shape{ .circle = .init(.xy(0, -5), 5) });
    world.add(npc, Interact{});
    world.add(npc, Dialog{ .lines = &.{"你好"} });
    return npc;
}

test "interact 按下交互键会给最近目标挂交互标记" {
    zhu.input.reset();
    defer zhu.input.reset();

    const oldGrid = map.grid;
    map.grid = .{ .width = 3, .height = 3, .cell = 16 };
    defer map.grid = oldGrid;

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    _ = addTestPlayer(&world, .xy(0, 0));
    const near = addTestNpc(&world, .xy(0, 10));
    const far = addTestNpc(&world, .xy(0, 18));

    zhu.key.set(.F, true);
    update(&world);

    try std.testing.expectEqual(near, world.getIdentity(Interact).?);
    try std.testing.expect(!world.isIdentity(far, Interact));
    try std.testing.expectEqual(0, world.values(Hit).len);
}

test "interact 对话中不会重新寻找目标" {
    zhu.input.reset();
    defer zhu.input.reset();

    const oldGrid = map.grid;
    map.grid = .{ .width = 3, .height = 3, .cell = 16 };
    defer map.grid = oldGrid;

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    _ = addTestPlayer(&world, .xy(0, 0));
    const talking = addTestNpc(&world, .xy(0, 10));
    const target = addTestNpc(&world, .xy(0, 10));
    world.addIdentity(talking, Dialog);

    zhu.key.set(.F, true);
    update(&world);

    try std.testing.expectEqual(talking, world.getIdentity(Dialog).?);
    try std.testing.expectEqual(null, world.getIdentity(Interact));
    try std.testing.expect(world.has(target, Interact));
}

test "interact 下一帧会清理上一次交互目标" {
    zhu.input.reset();
    defer zhu.input.reset();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const target = world.createEntity();
    world.addIdentity(target, Interact);

    update(&world);

    try std.testing.expectEqual(null, world.getIdentity(Interact));
}

test "interact 玩家紧贴 NPC 上方朝下时探测框能命中" {
    const oldGrid = map.grid;
    map.grid = .{ .width = 3, .height = 3, .cell = 16 };
    defer map.grid = oldGrid;

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    // 玩家朝下站在 NPC 正上方，两圆相切：NPC 脚底恰在 pos.y+10。
    _ = addTestPlayer(&world, .xy(0, 0));
    const npc = addTestNpc(&world, .xy(0, 10));

    markFacingHits(&world);
    defer world.clear(Hit);

    // 修复前 down 探测框近边在 pos.y+12，会漏掉相切的 NPC。
    try std.testing.expect(world.has(npc, Hit));
}
