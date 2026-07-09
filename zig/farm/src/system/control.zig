const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const input = @import("../input.zig");
const Inventory = @import("../resource/Inventory.zig");
const map = @import("../map.zig");

const Actor = component.actor.Actor;
const Facing = component.actor.Facing;
const Player = component.actor.Player;
const Action = component.actor.Action;
const Busy = component.actor.Busy;
const WantUse = component.actor.WantUse;
const Position = component.Position;
const Target = component.ui.Target;
const Velocity = component.motion.Velocity;
const ItemEnum = component.item.ItemEnum;
const World = ecs.World;
const Entity = ecs.Entity;

const playerSpeed: f32 = 60;
const tileRange: i32 = 1;

pub fn update(world: *World) void {
    const player = world.getIdentity(Player).?;

    // 工具动作播放期间不接收新的移动和工具输入。
    if (world.has(player, Busy)) return;

    updateTargetAction(world, player);
    updateMovement(world, player);
}

pub fn draw(world: *World) void {
    const player = world.getIdentity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    const tileSize = map.grid.cellSize();
    const rect = zhu.Rect.init(target.position, tileSize);
    zhu.batch.drawRect(rect, .{ .color = target.color });
}

fn updateMovement(world: *World, player: Entity) void {
    if (world.has(player, Busy)) return;

    const direction = readDirection();
    const velocity = direction.scale(playerSpeed);
    world.getPtr(player, Velocity).?.value = velocity;

    const actor = world.getPtr(player, Actor).?;
    if (direction.length2() == 0) {
        actor.action = Action.idle;
        return;
    }

    actor.action = Action.walk;
    actor.facing = facingFromDirection(direction);
}

fn readDirection() zhu.Vector2 {
    var direction: zhu.Vector2 = .zero;
    if (input.held(.left)) direction.x -= 1;
    if (input.held(.right)) direction.x += 1;
    if (input.held(.up)) direction.y -= 1;
    if (input.held(.down)) direction.y += 1;

    if (direction.length2() > 1) return direction.normalize();
    return direction;
}

fn targetPosition(world: *World, player: Entity) ?zhu.Vector2 {
    if (input.mouseCaptured) return null;

    const playerPos = world.get(player, Position).?;
    const playerTile = map.grid.worldToCell(playerPos);
    const mouseWorld = zhu.camera.toWorld(zhu.window.mouse);
    const mouseTile = map.grid.worldToCell(mouseWorld);

    if (map.grid.cellToIndex(mouseTile) == null) return null;

    const outOfRangeX = @abs(mouseTile.x - playerTile.x) > tileRange;
    const outOfRangeY = @abs(mouseTile.y - playerTile.y) > tileRange;
    if (outOfRangeX or outOfRangeY) return null;

    return map.grid.cellToWorld(mouseTile);
}

fn updateTargetAction(world: *World, player: Entity) void {
    const target = world.getPtr(player, Target).?;
    target.active = false;

    const inv = world.getPtr(world.entity, Inventory).?;
    const item = inv.active() orelse return;
    if (!isTargetItem(item)) return;

    const position = targetPosition(world, player) orelse return;

    target.position = position;
    target.active = true;

    if (!input.mousePressed(.LEFT)) return;
    const actor = world.getPtr(player, Actor).?;
    const playerPos = world.get(player, Position).?;
    // 朝向按点击位置计算，目标格只负责工具结算。
    const mouseWorld = zhu.camera.toWorld(zhu.window.mouse);
    const direction = mouseWorld.sub(playerPos);
    if (!direction.approxEqual(.zero)) {
        actor.facing = facingFromDirection(direction);
    }

    actor.action = actionFromItem(item);
    world.getPtr(player, Velocity).?.value = .zero;
    world.add(player, WantUse{ .item = item, .target = position });
    world.add(player, Busy{});
}

fn isTargetItem(item: ItemEnum) bool {
    return switch (item) {
        .hoe, .water, .pickaxe, .axe, .sickle => true,
        .strawberrySeed, .potatoSeed => true,
        .strawberry, .potato, .timber, .stone => false,
    };
}

fn actionFromItem(item: ItemEnum) Action {
    return switch (item) {
        .hoe => .hoe,
        .water => .watering,
        .pickaxe => .pickaxe,
        .axe => .axe,
        .sickle => .sickle,
        .strawberrySeed, .potatoSeed => .planting,
        .strawberry, .potato, .timber, .stone => unreachable,
    };
}

fn facingFromDirection(direction: zhu.Vector2) Facing {
    if (@abs(direction.x) > @abs(direction.y)) {
        return if (direction.x < 0) .left else .right;
    }
    return if (direction.y < 0) .up else .down;
}

fn testInventory(world: *World) *Inventory {
    if (world.getPtr(world.entity, Inventory)) |inv| return inv;

    world.entity = world.createEntity();
    world.add(world.entity, Inventory{});
    return world.getPtr(world.entity, Inventory).?;
}

fn setActiveItem(world: *World, item: ItemEnum, count: u32) void {
    const inv = testInventory(world);
    inv.reset();
    _ = inv.add(item, count);
}

fn addTestPlayer(world: *World, position: zhu.Vector2) Entity {
    const player = world.createIdentity(Player);
    world.add(player, position);
    world.add(player, Velocity{});
    world.add(player, Actor{});
    world.add(player, Target{});
    return player;
}

const testTarget = zhu.Vector2.xy(32, 48);

test "玩家控制会把方向键写入速度" {
    zhu.input.reset();
    defer zhu.input.reset();

    zhu.key.set(.D, true);
    zhu.key.set(.W, true);

    var world = World.init(std.testing.allocator);
    defer world.deinit();
    _ = testInventory(&world);

    const player = addTestPlayer(&world, .xy(24, 40));
    setActiveItem(&world, .strawberry, 1);

    update(&world);

    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.x > 0);
    try std.testing.expect(velocity.value.y < 0);
    const speed = velocity.value.length();
    try std.testing.expectApproxEqAbs(playerSpeed, speed, 0.01);

    const actor = world.get(player, Actor).?;
    try std.testing.expectEqual(Action.walk, actor.action);
    try std.testing.expectEqual(Facing.up, actor.facing);
}

test "忙碌状态会跳过输入并保持动作" {
    zhu.input.reset();
    defer zhu.input.reset();

    zhu.key.set(.D, true);

    var world = World.init(std.testing.allocator);
    defer world.deinit();
    _ = testInventory(&world);

    const player = addTestPlayer(&world, .xy(24, 40));
    world.getPtr(player, Actor).?.action = .hoe;
    world.add(player, Busy{});

    update(&world);

    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.approxEqual(.zero));
    const actor = world.get(player, Actor).?;
    try std.testing.expectEqual(Action.hoe, actor.action);
}

test "目标框只在工具或种子选中时显示" {
    zhu.input.reset();
    defer zhu.input.reset();

    zhu.camera.init(.xy(640, 360));
    zhu.window.mouse = .xy(32, 48);

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const player = addTestPlayer(&world, .xy(24, 40));
    setActiveItem(&world, .strawberry, 1);

    update(&world);
    try std.testing.expect(!world.get(player, Target).?.active);

    setActiveItem(&world, .hoe, 1);
    update(&world);
    try std.testing.expect(world.get(player, Target).?.active);
}

test "点击目标只写入使用意图" {
    zhu.input.reset();
    defer zhu.input.reset();

    zhu.camera.init(.xy(640, 360));
    zhu.window.mouse = testTarget;
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    setActiveItem(&world, .hoe, 1);
    zhu.mouse.set(.LEFT, true);

    const player = addTestPlayer(&world, .xy(24, 40));

    update(&world);

    try std.testing.expect(world.has(player, Busy));
    const actor = world.get(player, Actor).?;
    try std.testing.expectEqual(Action.hoe, actor.action);
    try std.testing.expect(world.get(player, Target).?.active);
    const want = world.get(player, WantUse).?;
    try std.testing.expectEqual(ItemEnum.hoe, want.item);
    try std.testing.expect(want.target.approxEqual(testTarget));
    const velocity = world.get(player, Velocity).?;
    try std.testing.expect(velocity.value.approxEqual(.zero));
}
