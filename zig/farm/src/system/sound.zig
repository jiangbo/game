const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");

const event = component.event;
const Position = component.Position;
const Emit = component.sound.Emit;
const Id = component.sound.Id;

pub fn update(world: *ecs.World) void {
    playEvents(world);
    playEntities(world);
}

fn playEvents(world: *ecs.World) void {
    const sounds = world.getEvent(event.SoundPlay);
    for (sounds) |evt| zhu.audio.playSound(path(evt.id));
    world.clearEvent(event.SoundPlay);
}

fn playEntities(world: *ecs.World) void {
    var query = world.query(.{ Position, Id, Emit });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        const id = query.get(entity, Id);
        const viewport = zhu.camera.viewport();
        if (!viewport.contains(position)) continue;

        const center = viewport.center();
        const halfWidth = viewport.size.x * 0.5;
        const offset = (position.x - center.x) / halfWidth;
        const pan = std.math.clamp(offset, -1, 1);

        _ = zhu.audio.playSoundOption(path(id), .{
            .left = 1 - @max(pan, 0),
            .right = 1 + @min(pan, 0),
        });
    }
    world.clear(Emit);
}

fn path(id: Id) [:0]const u8 {
    return switch (id) {
        .hoe => "audio/shovel-stab.ogg",
        .water => "audio/water_splash.ogg",
        .harvest => "audio/plant_harvest.ogg",
        .pickup => "audio/pop.ogg",
        .plant => "audio/planting-sounds.ogg",
        .axe => "audio/chop-wood.ogg",
        .pickaxe => "audio/pick-axe-striking.ogg",
        .cow => "audio/calf-and-cow.ogg",
        .sheep => "audio/sheep-baaing-3.ogg",
    };
}

test "sound id 映射到音频文件" {
    try std.testing.expectEqualStrings(
        "audio/shovel-stab.ogg",
        path(.hoe),
    );
    try std.testing.expectEqualStrings(
        "audio/water_splash.ogg",
        path(.water),
    );
    try std.testing.expectEqualStrings(
        "audio/pop.ogg",
        path(.pickup),
    );
    try std.testing.expectEqualStrings(
        "audio/chop-wood.ogg",
        path(.axe),
    );
    try std.testing.expectEqualStrings(
        "audio/pick-axe-striking.ogg",
        path(.pickaxe),
    );
    try std.testing.expectEqualStrings(
        "audio/calf-and-cow.ogg",
        path(.cow),
    );
    try std.testing.expectEqualStrings(
        "audio/sheep-baaing-3.ogg",
        path(.sheep),
    );
}

test "sound update 消费播放事件" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.addEvent(event.SoundPlay{ .id = .hoe });
    world.addEvent(event.SoundPlay{ .id = .pickup });

    update(&world);

    const sounds = world.getEvent(event.SoundPlay);
    try std.testing.expectEqual(0, sounds.len);
}

test "sound update 消费实体播放标记" {
    zhu.camera.init(.xy(320, 180));

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(160, 90));
    world.add(entity, Id.cow);
    world.add(entity, Emit{});

    update(&world);

    try std.testing.expect(!world.has(entity, Emit));
}

test "sound update 消费视野外实体播放标记" {
    zhu.camera.init(.xy(320, 180));

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(400, 90));
    world.add(entity, Id.sheep);
    world.add(entity, Emit{});

    update(&world);

    try std.testing.expect(!world.has(entity, Emit));
}
