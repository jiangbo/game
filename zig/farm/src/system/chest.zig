const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const factory = @import("../factory.zig");
const Inventory = @import("../resource/Inventory.zig");
const Notice = @import("../resource/Notice.zig");

const World = ecs.World;
const Interact = component.actor.Interact;
const ItemEnum = component.item.ItemEnum;
const Chest = component.item.Chest;
const Animation = component.actor.Animation;
const Shape = component.motion.Shape;

pub fn update(world: *World) void {
    const target = world.getIdentity(Interact) orelse return;
    if (!world.has(target, Chest)) return;

    const chest = world.getPtr(target, Chest).?;
    const notice = world.getPtr(world.entity, Notice).?;

    // 宝箱奖励允许部分领取，背包满时剩余数量留在宝箱里。
    var taken = Chest{ .items = .initFill(0) };
    for (std.enums.values(ItemEnum)) |itemType| {
        const count = chest.items.get(itemType);
        if (count == 0) continue;

        const inv = world.getPtr(world.entity, Inventory).?;
        const remaining = inv.add(itemType, count);
        chest.items.set(itemType, remaining);
        taken.items.set(itemType, count - remaining);
    }

    const full = hasItems(chest);
    showNotice(&taken, full, notice);
    if (full) return;

    chest.opened = true;

    const animation = world.getPtr(target, Animation).?;
    // anim_id 地图摆件已经是非循环动画，交互只负责重新播放。
    animation.reset();
    world.remove(target, Shape);
}

fn hasItems(chest: *const Chest) bool {
    for (std.enums.values(ItemEnum)) |itemType| {
        if (chest.items.get(itemType) > 0) return true;
    }
    return false;
}

fn showNotice(chest: *const Chest, full: bool, notice: *Notice) void {
    var buffer: [160]u8, var len: usize = .{ undefined, 0 };
    for (std.enums.values(ItemEnum)) |itemType| {
        const count = chest.items.get(itemType);
        if (count == 0) continue;

        const line = zhu.format(buffer[len..], "{s}获得 {s} x{d}", .{
            if (len == 0) "" else "\n",
            factory.itemConfig(itemType).name,
            count,
        });
        len += line.len;
    }

    if (full) {
        const line = zhu.format(buffer[len..], "{s}背包已满", .{
            if (len == 0) "" else "\n",
        });
        len += line.len;
    }

    if (len == 0) return;
    notice.show("{s}", .{buffer[0..len]});
}

fn addTestChest(world: *World, itemType: ItemEnum, count: u32) ecs.Entity {
    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .zero },
        .{ .offset = .xy(16, 0) },
    };
    var items = Chest{ .items = .initFill(0) };
    items.items.set(itemType, count);

    var animation = Animation.init(
        zhu.Image{ .size = .xy(32, 16) },
        .xy(16, 16),
        &frames,
    );
    animation.index = 1;

    const chest = world.createEntity();
    world.add(chest, items);
    world.add(chest, Interact{});
    world.add(chest, animation);
    world.add(chest, Shape{ .rect = .init(.zero, .xy(16, 16)) });
    return chest;
}

fn addTestInventory(world: *World) *Inventory {
    world.entity = world.createEntity();
    world.add(world.entity, Inventory{});
    world.add(world.entity, Notice{});
    return world.getPtr(world.entity, Inventory).?;
}

test "chest 交互会打开宝箱并移除碰撞" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    const inv = addTestInventory(&world);

    const chest = addTestChest(&world, .potato, 2);
    world.addIdentity(chest, Interact);

    update(&world);

    const chestState = world.get(chest, Chest).?;
    const animation = world.get(chest, Animation).?;

    try std.testing.expectEqual(chest, world.getIdentity(Interact).?);
    try std.testing.expect(chestState.opened);
    try std.testing.expectEqual(0, chestState.items.get(.potato));
    try std.testing.expectEqual(.potato, inv.store.stacks[0].item);
    try std.testing.expectEqual(2, inv.store.stacks[0].count);
    try std.testing.expectEqual(null, world.get(chest, Shape));
    try std.testing.expectEqual(0, animation.index);
}

test "chest 背包满时奖励留在宝箱里" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    const inv = addTestInventory(&world);

    for (&inv.store.stacks) |*stack| {
        stack.* = .{ .item = .hoe, .count = 1 };
    }

    const chest = addTestChest(&world, .potato, 2);
    world.addIdentity(chest, Interact);

    update(&world);

    const result = world.get(chest, Chest).?;
    try std.testing.expect(!result.opened);
    try std.testing.expectEqual(2, result.items.get(.potato));
    try std.testing.expect(world.has(chest, Shape));
    try std.testing.expectEqual(chest, world.getIdentity(Interact).?);
}
