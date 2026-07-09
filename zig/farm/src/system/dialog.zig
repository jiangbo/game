const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const input = @import("../input.zig");

const World = ecs.World;
const Entity = ecs.Entity;
const Position = component.Position;
const Player = component.actor.Player;
const Actor = component.actor.Actor;
const Dialog = component.actor.Dialog;
const Interact = component.actor.Interact;
const Velocity = component.motion.Velocity;

var bubbleImage: zhu.NineImage = undefined;

pub fn init() void {
    const image = zhu.getImage("farm-rpg/UI/dialogue box.png").?;
    bubbleImage = zhu.NineImage.from(image, .{
        .rect = .init(.xy(0, 48), .xy(48, 48)),
        .patch = .{ .min = .xy(3, 4), .max = .xy(3, 3) },
    });
}

pub fn update(world: *World) void {
    if (world.getIdentity(Dialog)) |target| {
        checkDistance(world, target);
        if (input.pressed(.interact)) advanceDialog(world, target);
        return;
    }

    const target = world.getIdentity(Interact) orelse return;
    if (!world.has(target, Dialog)) return;

    startDialog(world, target);
}

fn checkDistance(world: *World, target: Entity) void {
    const player = world.getIdentity(Player).?;
    const playerPos = world.get(player, Position).?;
    const targetPos = world.get(target, Position) orelse {
        closeDialog(world, target);
        return;
    };

    const dist = playerPos.sub(targetPos).length();
    if (dist > Dialog.closeDist) closeDialog(world, target);
}

fn startDialog(world: *World, target: Entity) void {
    const dialog = world.getPtr(target, Dialog).?;
    if (dialog.lines.len == 0) return;

    dialog.index = 0;
    facePlayer(world, target);
    world.addIdentity(target, Dialog);
}

fn facePlayer(world: *World, target: Entity) void {
    const player = world.getIdentity(Player).?;
    const playerPos = world.get(player, Position).?;
    const targetPos = world.get(target, Position).?;

    // 对话开始时 NPC 停下，并面向玩家。
    if (world.getPtr(target, Velocity)) |velocity| {
        velocity.value = .zero;
    }
    const actor = world.getPtr(target, Actor).?;
    actor.action = .idle;

    const direction = playerPos.sub(targetPos);
    if (!direction.approxEqual(.zero)) {
        actor.facing = facingFromDirection(direction);
    }
}

fn facingFromDirection(direction: zhu.Vector2) component.actor.Facing {
    if (@abs(direction.x) > @abs(direction.y)) {
        return if (direction.x < 0) .left else .right;
    }
    return if (direction.y < 0) .up else .down;
}

fn advanceDialog(world: *World, target: Entity) void {
    const dialog = world.getPtr(target, Dialog) orelse {
        closeDialog(world, target);
        return;
    };

    dialog.index += 1;
    if (dialog.index >= dialog.lines.len) closeDialog(world, target);
}

fn closeDialog(world: *World, target: Entity) void {
    const active = world.getIdentity(Dialog) orelse return;
    if (active != target) return;

    if (world.getPtr(target, Dialog)) |dialog| dialog.index = 0;
    world.removeIdentity(Dialog);
}

pub fn draw(world: *World) void {
    const entity = world.getIdentity(Dialog) orelse return;
    const dialog = world.get(entity, Dialog).?;
    if (dialog.index >= dialog.lines.len) return;

    const position = world.get(entity, Position).?;
    const head = zhu.camera.toWindow(position.addY(-24));
    zhu.camera.push(.window);
    defer zhu.camera.pop();
    drawBubble(head, dialog.lines[dialog.index]);
}

fn drawBubble(head: zhu.Vector2, text: []const u8) void {
    // head 是 NPC 头顶的窗口坐标，气泡和文字按窗口尺寸绘制。
    const option = zhu.text.Option{ .color = .black, .max = 144 };
    const textSize = zhu.text.measure(text, option);
    const size = textSize.add(.xy(16, 16)).max(.xy(160, 48));

    // 对话气泡在窗口坐标取整，避免位图文字亚像素闪烁。
    const bubblePos = head.addXY(-size.x / 2, -4 - size.y).round();
    const bubbleRect: zhu.Rect = .init(bubblePos, size);
    zhu.batch.drawNine(bubbleImage, bubbleRect);

    zhu.text.draw(text, bubbleRect.min.add(.xy(8, 8)), option);
}

fn addTestPlayer(world: *World, position: Position) Entity {
    const player = world.createIdentity(Player);
    world.add(player, position);
    return player;
}

fn addTestNpc(world: *World, position: Position) Entity {
    const npc = world.createEntity();
    world.add(npc, position);
    world.add(npc, Actor{});
    world.add(npc, Velocity{ .value = .xy(1, 0) });
    world.add(npc, Dialog{ .lines = &.{ "你好", "再见" } });
    return npc;
}

test "dialog 消费交互标记并开始对话" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    _ = addTestPlayer(&world, .xy(0, 0));
    const npc = addTestNpc(&world, .xy(0, 10));
    world.addIdentity(npc, Interact);

    update(&world);

    try std.testing.expectEqual(npc, world.getIdentity(Dialog).?);
    try std.testing.expectEqual(npc, world.getIdentity(Interact).?);
    try std.testing.expect(world.get(npc, Velocity).?.value.approxEqual(.zero));
    try std.testing.expectEqual(.up, world.get(npc, Actor).?.facing);
}

test "dialog 对话中按交互键会推进并关闭" {
    zhu.input.reset();
    defer zhu.input.reset();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    _ = addTestPlayer(&world, .xy(0, 0));
    const npc = addTestNpc(&world, .xy(0, 10));
    world.getPtr(npc, Dialog).?.lines = &.{"你好"};
    world.addIdentity(npc, Dialog);

    zhu.key.set(.F, true);
    update(&world);

    try std.testing.expectEqual(null, world.getIdentity(Dialog));
    try std.testing.expectEqual(@as(usize, 0), world.get(npc, Dialog).?.index);
}

test "dialog 距离过远会关闭对话" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    _ = addTestPlayer(&world, .xy(0, 0));
    const npc = addTestNpc(&world, .xy(0, 128));
    world.addIdentity(npc, Dialog);

    update(&world);

    try std.testing.expectEqual(null, world.getIdentity(Dialog));
}
