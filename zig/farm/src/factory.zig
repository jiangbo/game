const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");

const actor = component.actor;
const farm = component.farm;
const item = component.item;
const light = component.light;
const map = component.map;
const motion = component.motion;
const render = component.render;
const sound = component.sound;
const ui = component.ui;

const World = ecs.World;
const Entity = ecs.Entity;
const Sources = []const zhu.Animation.Source;
const tiled = zhu.extend.tiled;
const Object = tiled.Object;

pub const Animation = struct {
    type: actor.Action,
    imageId: zhu.graphics.ImageId,
    frames: []const zhu.graphics.Frame,
};

pub const Actor = struct {
    sprite: Sprite,
    rows: [4]i8,
    animations: []const Animation,
};

pub const Character = struct {
    sprite: Sprite,
    rows: [4]i8,
    animations: []const Animation,
    speed: f32,
    wanderRadius: f32,
    soundId: ?sound.Id = null,
    voice: ?sound.Voice = null,
    name: []const u8,
    dialog: []const []const u8 = &.{},
};

pub const Sprite = struct {
    imageId: zhu.graphics.ImageId,
    rect: zhu.Rect,
    offset: zhu.Vector2 = .zero,
    size: zhu.Vector2,
};

pub const Item = struct {
    name: []const u8,
    category: []const u8,
    description: []const u8,
    limit: u32 = 99,
    icon: Sprite,
    product: ?item.Product = null,
    health: ?u8 = null,
    hit: ?item.Hit = null,
};

pub const CropStage = struct { sprite: Sprite, duration: f32 };
// 单种作物的所有生长阶段配置
pub const CropConfig = struct { stages: [4]CropStage };

pub const Config = struct {
    player: Actor,
    items: [std.meta.fields(item.ItemEnum).len]Item,
    animals: [std.meta.fields(actor.AnimalEnum).len]Character,
    friend: Character,
    // crops 按 farm.CropEnum 枚举下标索引，每种作物对应一组阶段配置
    crops: [std.meta.fields(farm.CropEnum).len]CropConfig,
};

pub const zon: Config = @import("zon/factory.zon");

pub fn itemConfig(itemType: item.ItemEnum) Item {
    return zon.items[@intFromEnum(itemType)];
}

// 从 CropEnum 得到对应的种子 ItemEnum
pub fn seedItem(kind: farm.CropEnum) item.ItemEnum {
    return switch (kind) {
        .strawberry => .strawberrySeed,
        .potato => .potatoSeed,
    };
}

// 从 CropEnum 得到对应的产出 ItemEnum
pub fn harvestItem(kind: farm.CropEnum) item.ItemEnum {
    return switch (kind) {
        .strawberry => .strawberry,
        .potato => .potato,
    };
}

pub fn cropStage(kind: farm.CropEnum, stage: farm.GrowthEnum) CropStage {
    return zon.crops[@intFromEnum(kind)].stages[@intFromEnum(stage)];
}

pub fn resolveImage(sprite: Sprite) zhu.graphics.Image {
    return zhu.assets.getImage(sprite.imageId).?.sub(sprite.rect);
}

pub fn spawnPlayer(world: *World, spawn: zhu.Vector2) void {
    if (world.getIdentity(actor.Player)) |oldPlayer| {
        world.destroyEntity(oldPlayer);
        world.removeIdentity(actor.Player);
    }

    const config = zon.player;

    const player = world.createIdentity(actor.Player);
    world.add(player, spawn);
    world.add(player, motion.Velocity{});
    world.add(player, motion.Shape{
        .circle = .init(.xy(0, -5), 5),
    });
    world.add(player, motion.Blocking{});
    world.add(player, actor.Actor{ .rows = config.rows });

    const sources = comptime animationSources(config.animations);
    const size = config.sprite.rect.size;
    const animation = zhu.Animation.initSource(&sources, size);

    world.add(player, render.Sprite{
        .image = animation.subImage(),
        .offset = config.sprite.offset,
        .size = config.sprite.size,
    });

    world.add(player, animation);
    world.add(player, render.Render{ .layer = .actor });
    world.add(player, render.YSort{});
    world.add(player, ui.Target{});
}

pub fn spawnAnimal(world: *World, kind: actor.Animal) Entity {
    const config = zon.animals[@intFromEnum(kind)];

    // inline else 让每种动物的动画源在编译期按枚举值分别计算
    const sources = blk: switch (kind) {
        inline else => |k| {
            const source = zon.animals[@intFromEnum(k)].animations;
            break :blk &comptime animationSources(source);
        },
    };

    const entity = spawnNpc(world, config, sources);
    world.add(entity, kind);
    const interval = actor.Life.eatInterval;
    world.add(entity, actor.Life{
        .timer = zhu.random.float(interval * 0.5, interval),
    });
    if (config.soundId) |id| world.add(entity, id);
    if (config.voice) |voice| world.add(entity, voice);
    return entity;
}

pub fn spawnFriend(world: *World) Entity {
    // friend 动画源在编译期计算，配置缺失会直接编译失败。
    const sources = comptime animationSources(zon.friend.animations);
    return spawnNpc(world, zon.friend, &sources);
}

fn spawnNpc(world: *World, config: Character, sources: Sources) Entity {
    const entity = world.createEntity();
    world.add(entity, motion.Velocity{});
    world.add(entity, motion.Shape{
        .circle = .init(.xy(0, -5), 5),
    });
    world.add(entity, motion.Blocking{});
    world.add(entity, actor.Actor{ .rows = config.rows });
    const imageSize = config.sprite.rect.size;
    const animation = zhu.Animation.initSource(sources, imageSize);

    world.add(entity, render.Sprite{
        .image = animation.subImage(),
        .offset = config.sprite.offset,
        .size = config.sprite.size,
    });
    world.add(entity, animation);
    world.add(entity, render.Render{ .layer = .actor });
    world.add(entity, render.YSort{});
    world.add(entity, actor.Npc{});
    world.add(entity, actor.Wander{
        .radius = config.wanderRadius,
        .speed = config.speed,
    });
    if (config.dialog.len != 0) {
        world.add(entity, actor.Interact{});
        world.add(entity, actor.Dialog{ .lines = config.dialog });
    }

    return entity;
}

pub fn spawnMapObject(
    world: *World,
    data: tiled.Map,
    object: Object,
) Entity {
    const entity = world.createEntity();

    var image: zhu.graphics.Image = .empty;
    const tile = data.getTile(object.gid).?;
    if (data.getAnimation(object.gid)) |a| {
        var animation = a;
        image = animation.subImage();
        // anim_id 表示由玩法触发的动画，地图加载时只挂组件不自动播放。
        if (tile.hasProperty("anim_id")) {
            animation.loop = false;
            animation.stop();
        }
        world.add(entity, animation);
    } else {
        image = data.getImage(object.gid) orelse .empty;
    }

    const hasSize = object.size.x > 0 and object.size.y > 0;
    const size = if (hasSize) object.size else image.size;
    const drawPosition = object.position.addY(-size.y);
    const sortY = mapObjectSortY(object, tile, size);
    const sortPosition = zhu.Vector2.xy(object.position.x, sortY);

    world.add(entity, sortPosition);
    world.add(entity, render.Sprite{
        .image = image,
        .offset = drawPosition.sub(sortPosition),
        .size = size,
        .flip = object.extend.flipX,
    });
    world.add(entity, render.Render{ .layer = .actor });
    world.add(entity, render.YSort{});

    addMapItemProduct(world, entity, tile);

    // Tiled 转换数据沿用 obj_type，值为 chest 时挂宝箱组件。
    if (tile.getProperty("obj_type", []const u8)) |kind| {
        if (std.mem.eql(u8, kind, "chest")) {
            world.add(entity, actor.Interact{});
            world.add(entity, item.Chest{ .items = chestItems(object) });
        }
    }

    return entity;
}

pub fn spawnMapTile(
    world: *World,
    data: tiled.Map,
    globalId: u32,
    index: usize,
) Entity {
    const topLeft = data.grid.indexToWorld(index);
    const size = data.grid.cellSize();
    const position = topLeft.addY(size.y);
    var image = data.getImage(globalId) orelse
        zhu.graphics.Image{ .size = size };
    const entity = world.createEntity();

    if (data.getAnimation(globalId)) |baseAnimation| {
        var animation = baseAnimation;
        animation.loop = false;
        animation.stop();
        image = animation.subImage();
        world.add(entity, animation);
    }

    // tile layer 没有 Tiled object，统一用瓦片底边作为排序点。
    world.add(entity, position);
    world.add(entity, render.Sprite{
        .image = image,
        .offset = topLeft.sub(position),
        .size = size,
    });
    world.add(entity, render.Render{ .layer = .actor });
    world.add(entity, render.YSort{});

    if (data.getTile(globalId)) |tile| {
        addMapItemProduct(world, entity, tile);
    }
    return entity;
}

fn addMapItemProduct(
    world: *World,
    entity: Entity,
    tile: *const tiled.Tile,
) void {
    const animation = tile.getProperty("anim_id", []const u8) orelse return;
    const tool = std.meta.stringToEnum(item.ItemEnum, animation) orelse return;
    const hit = itemConfig(tool).hit orelse return;
    const config = itemConfig(hit.target);

    // 产出和生命值来自 ZON，anim_id 只负责选中工具配置。
    world.add(entity, config.product.?);
    world.add(entity, item.Health{ .value = config.health.? });
}

fn chestItems(object: Object) item.Counts {
    var result = item.Counts.initFill(0);

    for (std.enums.values(item.ItemEnum)) |itemType| {
        const count = object.getProperty(@tagName(itemType), u32);
        result.set(itemType, count orelse continue);
    }
    return result;
}

fn mapObjectSortY(
    object: Object,
    tile: *const tiled.Tile,
    size: zhu.Vector2,
) f32 {
    const group = tile.objectGroup orelse return object.position.y;
    var result: f32 = 0;
    var found = false;

    for (group.objects) |local| {
        if (local.size.x <= 0 or local.size.y <= 0) continue;

        // Tiled 瓦片对象 position 是图片底边，碰撞框坐标从图片左上角开始。
        const bottom = object.position.y - size.y +
            local.position.y + local.size.y;
        if (!found or bottom > result) {
            result = bottom;
            found = true;
        }
    }

    return if (found) result else object.position.y;
}

pub fn spawnMapTrigger(world: *World, trigger: map.Trigger) Entity {
    const entity = world.createEntity();
    world.add(entity, trigger);
    return entity;
}

pub fn spawnPointLight(world: *World, object: Object) Entity {
    const entity = world.createEntity();
    world.add(entity, light.Point{
        .radius = object.getProperty("radius", f32) orelse 96,
    });
    world.add(entity, object.position);
    applyLight(world, entity, object);
    return entity;
}

pub fn spawnSpotLight(world: *World, object: Object) Entity {
    const entity = world.createEntity();
    const spot = object.getClass("spot").?;
    std.debug.assert(spot.is("Spotlight"));
    world.add(entity, light.Spot{
        .radius = spot.get("radius", f32).?,
        .direction = spotDirection(spot),
    });
    world.add(entity, object.position);
    applyLight(world, entity, object);
    return entity;
}

fn spotDirection(spot: zhu.extend.tiled.ClassProperty) zhu.Vector2 {
    const degrees = spot.get("direction_deg", f32).?;
    const radians = std.math.degreesToRadians(degrees);
    return .xy(@cos(radians), @sin(radians));
}

// 根据 Tiled 属性设置灯光的昼夜可见性
fn applyLight(world: *World, entity: Entity, object: Object) void {
    const day = object.getProperty("day_only", bool) orelse false;
    const night = object.getProperty("night_only", bool) orelse !day;
    world.addAll(entity, .{ light.Disabled{}, light.Pending{} });

    if (day) world.add(entity, light.Day{});

    if (night) world.add(entity, light.Night{});
}

pub fn spawnCrop(
    world: *World,
    position: zhu.Vector2,
    kind: farm.CropEnum,
) Entity {
    const stage = zon.crops[@intFromEnum(kind)].stages[0];
    const entity = world.createEntity();
    // kind 写入组件，后续 advanceCrop 依赖它查找正确的阶段贴图
    world.add(entity, farm.Crop{ .kind = kind, .next = stage.duration });
    world.add(entity, component.Position.xy(position.x, position.y));
    world.add(entity, render.Sprite{
        .image = resolveImage(stage.sprite),
        .offset = stage.sprite.offset,
    });
    world.add(entity, render.Render{ .layer = .crop });
    world.add(entity, render.YSort{});
    return entity;
}

pub fn advanceCrop(crop: *farm.Crop) render.Sprite {
    crop.timer = 0;
    crop.stage = zhu.enums.next(crop.stage);
    // 用 crop.kind 查找该作物对应阶段的贴图
    const stage = cropStage(crop.kind, crop.stage);
    crop.next = stage.duration;
    return .{
        .image = resolveImage(stage.sprite),
        .offset = stage.sprite.offset,
    };
}

pub fn spawnPickup(world: *World, args: struct {
    item: item.ItemEnum,
    count: u32 = 1,
    origin: zhu.Vector2,
}) void {
    const config = itemConfig(args.item);
    const image = resolveImage(config.icon);
    // 地图掉落物使用原始像素尺寸，背包图标才使用配置中的 UI 尺寸。
    const size = image.size;
    const offset = size.scale(-0.5);

    // 在图标大小范围内随机一个落点，作为出生飞散动画的终点。
    const radius = @sqrt(zhu.random.float(0, 1)) * size.maxAxis();
    const angle = zhu.random.float(0, std.math.tau);
    const scatter = zhu.Vector2.xy(@cos(angle), @sin(angle)).scale(radius);

    const entity = world.createEntity();
    world.add(entity, args.origin);
    world.add(entity, item.Pickup{
        .item = args.item,
        .count = args.count,
    });
    world.add(entity, item.PickupMotion{
        .start = args.origin,
        .target = args.origin.add(scatter),
    });
    world.add(entity, motion.Shape{ .rect = .init(offset, size) });
    world.add(entity, render.Sprite{
        .image = image,
        .offset = offset,
        .size = size,
    });
    world.add(entity, render.Render{ .layer = .crop });
    world.add(entity, render.YSort{});
}

// 动画源数组按 Action 枚举全长定长，未配置的动作留空 Source。
// 角色只会切到已配置动画的动作，空槽不会被访问到。
const actionCount = std.meta.fields(actor.Action).len;

fn animationSources(comptime animations: []const Animation) //
[actionCount]zhu.Animation.Source {
    var sources: [actionCount]zhu.Animation.Source =
        std.mem.zeroes([actionCount]zhu.Animation.Source);
    for (animations) |config| {
        sources[@intFromEnum(config.type)] = .{
            .imageId = config.imageId,
            .clip = config.frames,
        };
    }
    return sources;
}

const expectEqual = std.testing.expectEqual;
test "spawnPlayer 会创建玩家实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockFarmImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    spawnPlayer(&world, .xy(160, 96));

    const player = world.getIdentity(actor.Player).?;
    try expectEqual(160, world.get(player, component.Position).?.x);
    try expectEqual(1, world.values(motion.Velocity).len);
    try expectEqual(1, world.values(actor.Actor).len);
    try expectEqual(1, world.values(render.Sprite).len);
    try expectEqual(1, world.values(render.Render).len);
    try expectEqual(1, world.values(render.YSort).len);
}

test "spawnPlayer 重复调用只保留一个玩家" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockFarmImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    spawnPlayer(&world, .xy(160, 96));
    spawnPlayer(&world, .xy(200, 128));

    const player = world.getIdentity(actor.Player).?;
    try expectEqual(200, world.get(player, component.Position).?.x);
    try expectEqual(1, world.values(component.Position).len);
    try expectEqual(1, world.values(motion.Velocity).len);
    try expectEqual(1, world.values(actor.Actor).len);
}

test "spawnAnimal 会创建可漫游动物实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockAnimalImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnAnimal(&world, .cow);

    try expectEqual(actor.AnimalEnum.cow, world.get(entity, actor.Animal).?);
    try std.testing.expect(world.has(entity, actor.Npc));
    try std.testing.expect(world.has(entity, actor.Wander));
    try std.testing.expect(world.has(entity, actor.Life));
    try expectEqual(sound.Id.cow, world.get(entity, sound.Id).?);
    try expectEqual(0.4, world.get(entity, sound.Voice).?.probability);
    const life = world.get(entity, actor.Life).?;
    try std.testing.expectEqual(.normal, life.state);
    try std.testing.expect(life.timer >= 4);
    try std.testing.expect(life.timer <= 8);
    try expectEqual(null, world.get(entity, actor.Dialog));
}

test "spawnFriend 会创建可对话 NPC 实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockNpcImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnFriend(&world);

    try std.testing.expect(world.has(entity, actor.Npc));
    try std.testing.expect(world.has(entity, actor.Wander));
    try std.testing.expect(world.has(entity, actor.Interact));
    const dialog = world.get(entity, actor.Dialog).?;
    try std.testing.expect(dialog.lines.len != 0);
}

test "spawnCrop 会按作物类型设置 kind 和 next" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const cases = [_]struct {
        kind: farm.CropEnum,
        position: zhu.Vector2,
    }{
        .{ .kind = .strawberry, .position = .xy(32, 48) },
        .{ .kind = .potato, .position = .xy(64, 80) },
    };

    for (cases) |case| {
        const entity = spawnCrop(&world, case.position, case.kind);
        const crop = world.get(entity, farm.Crop).?;
        const config = zon.crops[@intFromEnum(case.kind)];

        try expectEqual(farm.GrowthEnum.seed, crop.stage);
        try expectEqual(case.kind, crop.kind);
        try expectEqual(config.stages[0].duration, crop.next);
        const position = world.get(entity, component.Position).?;
        try expectEqual(case.position.x, position.x);
    }
}

test "advanceCrop 会推进阶段并保持 kind" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();
    putMockCropImages();

    const kinds = [_]farm.CropEnum{ .strawberry, .potato };
    for (kinds) |kind| {
        const config = zon.crops[@intFromEnum(kind)];
        var crop = farm.Crop{
            .kind = kind,
            .next = config.stages[0].duration,
        };

        _ = advanceCrop(&crop);

        try expectEqual(farm.GrowthEnum.sprout, crop.stage);
        try expectEqual(kind, crop.kind);
        try expectEqual(config.stages[1].duration, crop.next);
        try expectEqual(0, crop.timer);
    }
}

test "地图摆件按底边定位生成实体" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    const imageId = 1234;
    const tileSetId = 5678;
    const image = zhu.graphics.Image{ .size = .xy(16, 16) };
    zhu.assets.putImage(imageId, image);

    const tiles = [_]tiled.Tile{
        .{
            .id = imageId,
            .objectGroup = null,
            .properties = &.{},
            .animation = &.{},
        },
    };
    const tileSets = [_]tiled.TileSet{
        .{
            .id = tileSetId,
            .columns = 0,
            .tileCount = 1,
            .image = imageId,
            .tileSize = .xy(16, 16),
            .tiles = &tiles,
        },
    };
    const testMap = tiled.Map{
        .grid = .{ .width = 1, .height = 1, .cell = 16 },
        .layers = &.{},
        .tileSets = &tileSets,
    };

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnMapObject(&world, testMap, .{
        .id = 1,
        .gid = 0x01000000,
        .name = "",
        .type = "",
        .position = .xy(12, 34),
        .size = .xy(20, 30),
        .point = false,
        .properties = &.{},
        .extend = .{},
    });

    const position = world.get(entity, component.Position).?;
    const sprite = world.get(entity, render.Sprite).?;

    try expectEqual(12, position.x);
    try expectEqual(34, position.y);
    try expectEqual(-30, sprite.offset.y);
    try expectEqual(20, sprite.size.?.x);
    try expectEqual(30, sprite.size.?.y);
}

test "地图摆件优先用碰撞底边作为排序点" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    const imageId = 1234;
    const tileSetId = 5678;
    const image = zhu.graphics.Image{ .size = .xy(20, 40) };
    zhu.assets.putImage(imageId, image);

    const collisions = [_]tiled.Object{.{
        .id = 1,
        .gid = 0,
        .name = "",
        .type = "",
        .position = .xy(2, 12),
        .size = .xy(16, 8),
        .point = false,
        .properties = &.{},
        .extend = .{},
    }};
    const tiles = [_]tiled.Tile{.{
        .id = imageId,
        .objectGroup = .{ .visible = true, .objects = &collisions },
        .properties = &.{},
        .animation = &.{},
    }};
    const tileSets = [_]tiled.TileSet{.{
        .id = tileSetId,
        .columns = 0,
        .tileCount = 1,
        .image = imageId,
        .tileSize = .xy(20, 40),
        .tiles = &tiles,
    }};
    const testMap = tiled.Map{
        .grid = .{ .width = 1, .height = 1, .cell = 16 },
        .layers = &.{},
        .tileSets = &tileSets,
    };

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnMapObject(&world, testMap, .{
        .id = 1,
        .gid = 0x01000000,
        .name = "",
        .type = "",
        .position = .xy(12, 50),
        .size = .xy(20, 40),
        .point = false,
        .properties = &.{},
        .extend = .{},
    });

    const position = world.get(entity, component.Position).?;
    const sprite = world.get(entity, render.Sprite).?;

    try expectEqual(12, position.x);
    try expectEqual(30, position.y);
    try expectEqual(-20, sprite.offset.y);
    try expectEqual(10, position.y + sprite.offset.y);
}

test "带 anim_id 的地图摆件会创建停止的非循环动画" {
    zhu.assets.initCaches(std.testing.allocator);
    defer zhu.assets.deinit();

    const imageId = 1234;
    const tileSetId = 5678;
    const image = zhu.graphics.Image{ .size = .xy(32, 16) };
    zhu.assets.putImage(imageId, image);

    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .xy(0, 0), .duration = 0.1 },
        .{ .offset = .xy(16, 0), .duration = 0.1 },
    };
    const properties = [_]tiled.Property{
        .{ .name = "anim_id", .value = .{ .string = "open" } },
    };
    const tiles = [_]tiled.Tile{
        .{
            .id = 0,
            .objectGroup = null,
            .properties = &properties,
            .animation = &frames,
        },
    };
    const tileSets = [_]tiled.TileSet{
        .{
            .id = tileSetId,
            .columns = 2,
            .tileCount = 2,
            .image = imageId,
            .tileSize = .xy(16, 16),
            .tiles = &tiles,
        },
    };
    const testMap = tiled.Map{
        .grid = .{ .width = 1, .height = 1, .cell = 16 },
        .layers = &.{},
        .tileSets = &tileSets,
    };

    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const entity = spawnMapObject(&world, testMap, .{
        .id = 1,
        .gid = 0x01000000,
        .name = "",
        .type = "",
        .position = .xy(12, 34),
        .size = .zero,
        .point = false,
        .properties = &.{},
        .extend = .{},
    });

    const animation = world.get(entity, actor.Animation).?;
    const sprite = world.get(entity, render.Sprite).?;

    try std.testing.expect(!animation.loop);
    try std.testing.expect(animation.isFinished());
    try expectEqual(0, sprite.image.offset.x);
    try expectEqual(0, sprite.image.offset.y);
}

test "工具命中目标和资源耐久来自物品配置" {
    try expectEqual(item.ItemEnum.stone, itemConfig(.pickaxe).hit.?.target);
    try expectEqual(item.ItemEnum.timber, itemConfig(.axe).hit.?.target);

    try expectEqual(3, itemConfig(.stone).health.?);
    try expectEqual(5, itemConfig(.timber).health.?);
}

fn putMockFarmImages() void {
    const image = zhu.graphics.Image{ .size = .xy(256, 256) };

    for (zon.player.animations) |animation| {
        zhu.assets.putImage(animation.imageId, image);
    }
}

fn putMockCropImages() void {
    const image = zhu.graphics.Image{ .size = .xy(256, 256) };
    // 遍历所有作物种类的所有阶段
    for (zon.crops) |cropConfig| {
        for (cropConfig.stages) |stage| {
            zhu.assets.putImage(stage.sprite.imageId, image);
        }
    }
}

fn putMockAnimalImages() void {
    const image = zhu.graphics.Image{ .size = .xy(128, 288) };
    for (zon.animals) |animalConfig| {
        zhu.assets.putImage(animalConfig.sprite.imageId, image);
    }
}

fn putMockNpcImages() void {
    const image = zhu.graphics.Image{ .size = .xy(192, 96) };
    zhu.assets.putImage(zon.friend.sprite.imageId, image);
    for (zon.friend.animations) |animation| {
        zhu.assets.putImage(animation.imageId, image);
    }
}
