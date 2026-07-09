const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const factory = @import("../factory.zig");
const Inventory = @import("../resource/Inventory.zig");
const map = @import("../map.zig");

const Player = component.actor.Player;
const UseFrame = component.actor.UseFrame;
const WantUse = component.actor.WantUse;
const Animation = component.actor.Animation;
const Crop = component.farm.Crop;
const CropEnum = component.farm.CropEnum;
const ItemEnum = component.item.ItemEnum;
const Pickup = component.item.Pickup;
const Product = component.item.Product;
const Health = component.item.Health;
const event = component.event;
const World = ecs.World;

pub fn update(world: *World) void {
    const player = world.getIdentity(Player).?;
    if (!world.has(player, UseFrame)) return;

    useItem(world, world.get(player, WantUse).?);

    // 一次动作只结算一次，结算后清理关键帧标记和意图。
    world.remove(player, UseFrame);
    world.remove(player, WantUse);
}

fn useItem(world: *World, want: WantUse) void {
    // WantUse.item 是点击瞬间锁定的物品，不读取当前快捷栏状态。
    switch (want.item) {
        .hoe => if (map.hoe(want.target)) {
            world.addEvent(event.SoundPlay{ .id = .hoe });
        },
        .water => water(world, want.target),
        .sickle => harvest(world, want.target),
        .strawberrySeed => useSeed(world, want, .strawberry),
        .potatoSeed => useSeed(world, want, .potato),
        .pickaxe, .axe => hitProduct(world, want),
        .strawberry, .potato, .timber, .stone => unreachable,
    }
}

fn harvest(world: *World, position: zhu.Vector2) void {
    const tile = map.getTile(position) orelse return;
    const entity = tile.get(.crop) orelse return;
    const crop = world.get(entity, Crop).?;
    if (crop.stage != .mature) return;

    // 成熟作物先从地块移除，再生成一个可拾取产物。
    const item = factory.harvestItem(crop.kind);
    world.destroyEntity(entity);
    tile.object = null;
    factory.spawnPickup(world, .{
        .item = item,
        .origin = position.add(map.grid.halfCell()),
    });
    world.addEvent(event.SoundPlay{ .id = .harvest });
}

fn useSeed(world: *World, want: WantUse, kind: CropEnum) void {
    if (!map.canPlant(want.target)) return;
    const inv = world.getPtr(world.entity, Inventory).?;
    if (!inv.use(want.item, 1)) return;

    const crop = factory.spawnCrop(world, want.target, kind);
    map.getTile(want.target).?.set(.crop, crop);
    world.addEvent(event.SoundPlay{ .id = .plant });
}

fn water(world: *World, position: zhu.Vector2) void {
    if (!map.water(position)) return;

    const tile = map.getTile(position).?;
    if (tile.get(.crop)) |entity| {
        world.getPtr(entity, Crop).?.watered = true;
    }
    world.addEvent(event.SoundPlay{ .id = .water });
}

fn hitProduct(world: *World, want: WantUse) void {
    const hit = factory.itemConfig(want.item).hit.?;
    const tile = map.getTile(want.target) orelse return;
    const entity = tile.get(.product) orelse return;
    const product = world.get(entity, Product).?;
    if (product.value.item != hit.target) return;

    const health = world.getPtr(entity, Health).?;
    std.debug.assert(health.value > 0);
    health.value -= 1;
    // reset 后动画系统会在下一次 update 立即处理第一帧。
    if (world.getPtr(entity, Animation)) |a| a.reset();

    world.addEvent(event.SoundPlay{ .id = toolSound(want.item) });
    if (health.value != 0) return;

    // value.count 表示最大掉落数量，实际掉落 1 到 count 个，
    // 合并为一个带数量的掉落物，拾取时一次性获得全部。
    std.debug.assert(product.value.count > 0);
    const dropCount = zhu.random.intMost(u32, 1, product.value.count);
    const origin = want.target.add(map.grid.halfCell());
    factory.spawnPickup(world, .{
        .item = product.value.item,
        .count = dropCount,
        .origin = origin,
    });
    map.clearProduct(world, want.target);
}

fn toolSound(tool: ItemEnum) component.sound.Id {
    return switch (tool) {
        .axe => .axe,
        .pickaxe => .pickaxe,
        else => unreachable,
    };
}

const testMap = zhu.extend.tiled.Map{
    .grid = .{ .width = 4, .height = 5, .cell = 16 },
    .layers = &.{.{
        .id = 1,
        .name = "ground",
        .image = 0,
        .type = .tile,
        .offset = .zero,
        .data = &.{
            0, 0, 0,          0,
            0, 0, 0,          0,
            0, 0, 0,          0,
            0, 0, 0x01000000, 0x01000001,
            0, 0, 0,          0,
        },
        .objects = &.{},
    }},
    .tileSets = &.{.{
        .id = 1,
        .columns = 1,
        .tileCount = 1,
        .image = 0,
        .tileSize = .xy(16, 16),
        .tiles = &.{
            .{
                .id = 0,
                .objectGroup = null,
                .properties = &.{.{
                    .name = "tile_flag",
                    .value = .{ .string = "ARABLE" },
                }},
                .animation = &.{},
            },
            .{
                .id = 1,
                .objectGroup = null,
                .properties = &.{.{
                    .name = "tile_flag",
                    .value = .{ .string = "ARABLE,SOLID" },
                }},
                .animation = &.{},
            },
        },
    }},
};

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

fn putMockImages() void {
    const image = zhu.Image{ .size = .xy(256, 256) };
    for (factory.zon.crops) |cropConfig| {
        for (cropConfig.stages) |stage| {
            zhu.assets.putImage(stage.sprite.imageId, image);
        }
    }
    for (factory.zon.items) |item| {
        zhu.assets.putImage(item.icon.imageId, image);
    }
}

fn addProductEntity(
    world: *World,
    target: zhu.Vector2,
    product: Product,
    health: u8,
) ecs.Entity {
    const entity = world.createEntity();
    world.add(entity, product);
    world.add(entity, Health{ .value = health });
    map.getTile(target).?.set(.product, entity);
    return entity;
}

test "toolHit 会按 WantUse 锄地" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .hoe, .target = target });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expect(map.canPlant(target));
    try std.testing.expect(!world.has(player, WantUse));

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.hoe, sounds[0].id);
}

test "非事件帧不会结算 WantUse" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .hoe, .target = target });

    update(&world);

    try std.testing.expect(!map.canPlant(target));
    try std.testing.expect(world.has(player, WantUse));
}

test "seedPlant 会种植并扣种子" {
    const target = zhu.Vector2.xy(32, 48);
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const inv = testInventory(&world);
    setActiveItem(&world, .strawberrySeed, 2);
    try std.testing.expect(map.hoe(target));

    const player = world.createIdentity(Player);
    world.add(player, WantUse{
        .item = .strawberrySeed,
        .target = target,
    });
    world.add(player, UseFrame{});

    update(&world);

    const index = inv.hotbar[inv.activeHotbar].?;
    try std.testing.expectEqual(1, inv.store.stacks[index].count);

    const cropEntity = map.getTile(target).?.get(.crop).?;
    try std.testing.expectEqual(
        CropEnum.strawberry,
        world.get(cropEntity, Crop).?.kind,
    );

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.plant, sounds[0].id);
}

test "seedPlant 没有种子时不会种植" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    _ = testInventory(&world);
    try std.testing.expect(map.hoe(target));

    const player = world.createIdentity(Player);
    world.add(player, WantUse{
        .item = .strawberrySeed,
        .target = target,
    });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(null, map.getTile(target).?.get(.crop));
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}

test "seedPlant 无耕地时不扣种子" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const inv = testInventory(&world);
    setActiveItem(&world, .strawberrySeed, 2);

    const player = world.createIdentity(Player);
    world.add(player, WantUse{
        .item = .strawberrySeed,
        .target = target,
    });
    world.add(player, UseFrame{});

    update(&world);

    const index = inv.hotbar[inv.activeHotbar].?;
    try std.testing.expectEqual(2, inv.store.stacks[index].count);
    try std.testing.expectEqual(null, map.getTile(target).?.get(.crop));
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}

test "seedPlant 已有作物时不扣种子" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const inv = testInventory(&world);
    setActiveItem(&world, .strawberrySeed, 2);
    try std.testing.expect(map.hoe(target));
    const oldCrop = world.createEntity();
    world.add(oldCrop, Crop{ .kind = .potato });
    map.getTile(target).?.set(.crop, oldCrop);

    const player = world.createIdentity(Player);
    world.add(player, WantUse{
        .item = .strawberrySeed,
        .target = target,
    });
    world.add(player, UseFrame{});

    update(&world);

    const index = inv.hotbar[inv.activeHotbar].?;
    try std.testing.expectEqual(2, inv.store.stacks[index].count);
    try std.testing.expectEqual(oldCrop, map.getTile(target).?.get(.crop).?);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}

test "toolHit 会浇水并标记作物" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    try std.testing.expect(map.hoe(target));
    const crop = world.createEntity();
    world.add(crop, Crop{});
    map.getTile(target).?.set(.crop, crop);

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .water, .target = target });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expect(world.get(crop, Crop).?.watered);

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.water, sounds[0].id);
}

test "斧头命中木材产出对象会减少生命" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const entity = addProductEntity(
        &world,
        target,
        Product{ .value = .one(.timber) },
        2,
    );
    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .axe, .target = target });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(entity, map.getTile(target).?.get(.product).?);
    try std.testing.expectEqual(1, world.get(entity, Health).?.value);
    try std.testing.expectEqual(0, world.values(Pickup).len);

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.axe, sounds[0].id);
}

test "斧头命中产出对象会播放地图资源动画" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const entity = addProductEntity(
        &world,
        target,
        Product{ .value = .one(.timber) },
        2,
    );
    const image = zhu.Image{ .size = .xy(32, 16) };
    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .xy(0, 0), .duration = 0.1 },
        .{ .offset = .xy(16, 0), .duration = 0.1 },
    };
    var animation = Animation.init(image, .xy(16, 16), &frames);
    animation.loop = false;
    animation.stop();
    world.add(entity, animation);

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .axe, .target = target });
    world.add(player, UseFrame{});

    update(&world);

    const result = world.get(entity, Animation).?;
    try std.testing.expect(result.isRunning());
}

test "错误工具不会命中产出对象" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const entity = addProductEntity(
        &world,
        target,
        Product{ .value = .one(.stone) },
        2,
    );
    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .axe, .target = target });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(entity, map.getTile(target).?.get(.product).?);
    try std.testing.expectEqual(2, world.get(entity, Health).?.value);
    try std.testing.expectEqual(0, world.values(Pickup).len);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}

test "镐子击碎石头会生成掉落并清理阻挡" {
    const target = zhu.Vector2.xy(48, 48);
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    zhu.random.init(1);
    putMockImages();
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    const entity = addProductEntity(
        &world,
        target,
        Product{ .value = .{ .item = .stone, .count = 2 } },
        1,
    );
    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .pickaxe, .target = target });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(null, map.getTile(target).?.get(.product));
    try std.testing.expect(!world.has(entity, Product));
    try std.testing.expect(!map.hasAnyBlockAt(target.add(.xy(1, 1))));

    const pickups = world.values(Pickup);
    try std.testing.expectEqual(1, pickups.len);
    try std.testing.expectEqual(ItemEnum.stone, pickups[0].item);
    try std.testing.expect(pickups[0].count >= 1);
    try std.testing.expect(pickups[0].count <= 2);

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.pickaxe, sounds[0].id);
}

test "sickle 会收获成熟作物并生成掉落物" {
    const target = zhu.Vector2.xy(32, 48);
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockImages();
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    try std.testing.expect(map.hoe(target));
    const crop = world.createEntity();
    world.add(crop, Crop{ .stage = .mature, .kind = .potato });
    map.getTile(target).?.set(.crop, crop);

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .sickle, .target = target });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(null, map.getTile(target).?.get(.crop));
    try std.testing.expectEqual(null, world.get(crop, Crop));

    const pickups = world.values(Pickup);
    try std.testing.expectEqual(1, pickups.len);
    try std.testing.expectEqual(ItemEnum.potato, pickups[0].item);

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.harvest, sounds[0].id);
}

test "hoe 不会收获成熟作物" {
    const target = zhu.Vector2.xy(32, 48);
    var world = World.init(std.testing.allocator);
    defer world.deinit();
    map.load(zhu.testing.allocator, &world, testMap);
    defer map.unload(zhu.testing.allocator);

    try std.testing.expect(map.hoe(target));
    const crop = world.createEntity();
    world.add(crop, Crop{ .stage = .mature, .kind = .potato });
    map.getTile(target).?.set(.crop, crop);

    const player = world.createIdentity(Player);
    world.add(player, WantUse{ .item = .hoe, .target = target });
    world.add(player, UseFrame{});

    update(&world);

    try std.testing.expectEqual(crop, map.getTile(target).?.get(.crop).?);
    try std.testing.expectEqual(0, world.values(Pickup).len);
    try std.testing.expectEqual(0, world.getEvent(event.SoundPlay).len);
}
