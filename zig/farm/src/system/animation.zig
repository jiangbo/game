const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const Action = component.actor.Action;
const Actor = component.actor.Actor;
const Busy = component.actor.Busy;
const UseFrame = component.actor.UseFrame;
const Animation = component.actor.Animation;
const Sprite = component.render.Sprite;

pub fn update(world: *ecs.World, delta: f32) void {
    updateActor(world);

    var query = world.query(.{ Animation, Sprite });
    while (query.next()) |entity| {
        const animation = query.getPtr(entity, Animation);
        const sprite = query.getPtr(entity, Sprite);

        switch (animation.update(delta) orelse continue) {
            .next, .loop => {
                sprite.image = animation.subImage();
                if (animation.frame().extend == 0) continue;

                // extend 非零表示这一帧是动作生效点，具体效果由 farm 系统处理。
                query.add(world, entity, UseFrame{});
            },
            .end => {
                if (!world.has(entity, Busy)) continue;

                // 工具动画完整播放后恢复待机，下一帧控制系统才能再次接管。
                world.remove(entity, Busy);
                const actor = world.getPtr(entity, Actor).?;
                actor.action = .idle;

                const row = actorRow(actor, sprite);
                playActor(animation, .idle, row, true);
                sprite.image = animation.subImage();
            },
        }
    }
}

fn updateActor(world: *ecs.World) void {
    var query = world.query(.{ Actor, Animation, Sprite });
    while (query.next()) |entity| {
        const actor = query.getPtr(entity, Actor);
        const animation = query.getPtr(entity, Animation);
        const sprite = query.getPtr(entity, Sprite);

        const row = actorRow(actor, sprite);
        const index = zhu.toIndex(u8, actor.action);
        const sameAction = animation.sourceIndex == index;
        if (sameAction and animation.row == row) continue;

        const loop = actor.action == .idle or
            actor.action == .walk or actor.action == .sleep or
            actor.action == .eat;
        playActor(animation, actor.action, row, loop);
    }
}

fn playActor(animation: *Animation, action: Action, row: u8, loop: bool) void {
    animation.play(action, row);
    animation.source.loop = loop;
}

fn actorRow(actor: *const Actor, sprite: *Sprite) u8 {
    const raw = actor.rows[@backingInt(actor.facing)];
    sprite.flip = raw < 0;
    std.debug.assert(raw != 0);
    return @intCast(@abs(raw) - 1);
}

test "动画系统会按角色方向行更新精灵" {
    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .zero, .duration = 0.1 },
    };
    const image = zhu.Image{ .size = .xy(32, 32) };

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Actor{ .action = .walk, .facing = .left });
    const sources = [_]zhu.Animation.Source{
        .{ .imageId = 1, .frames = &frames, .size = image.size },
        .{ .imageId = 1, .frames = &frames, .size = image.size },
    };
    world.add(entity, Animation.initSource(&sources));
    world.add(entity, Sprite{ .image = image });

    update(&world, 0);

    const sprite = world.get(entity, Sprite).?;
    try std.testing.expect(sprite.flip);
    try std.testing.expectEqual(64, sprite.image.offset.y);
}

test "负数行号表示翻转" {
    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .zero, .duration = 0.1 },
    };
    const image = zhu.Image{ .size = .xy(32, 32) };

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Actor{
        .action = .idle,
        .facing = .right,
        .rows = .{ 1, 2, 3, -1 },
    });
    const sources = [_]zhu.Animation.Source{
        .{ .imageId = 1, .frames = &frames, .size = image.size },
    };
    world.add(entity, Animation.initSource(&sources));
    world.add(entity, Sprite{ .image = image });

    update(&world, 0);

    const sprite = world.get(entity, Sprite).?;
    try std.testing.expect(sprite.flip);
    try std.testing.expectEqual(0, sprite.image.offset.y);
}

test "工具动画结束后解除忙碌状态" {
    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .zero, .duration = 0.1 },
    };
    const image = zhu.Image{ .size = .xy(32, 32) };

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Actor{ .action = .hoe });
    const sources = [_]zhu.Animation.Source{
        .{ .imageId = 1, .frames = &frames, .size = image.size },
        .{ .imageId = 1, .frames = &frames, .size = image.size },
        .{ .imageId = 1, .frames = &frames, .size = image.size },
        .{ .imageId = 1, .frames = &frames, .size = image.size },
        .{ .imageId = 1, .frames = &frames, .size = image.size },
    };
    world.add(entity, Animation.initSource(&sources));
    world.add(entity, Sprite{ .image = image });
    world.add(entity, Busy{});

    update(&world, 0.01);
    update(&world, 0.2);

    try std.testing.expect(!world.has(entity, Busy));
    try std.testing.expectEqual(Action.idle, world.get(entity, Actor).?.action);
}

test "动画进入关键帧时挂上生效标记" {
    const frames = [_]zhu.graphics.Frame{
        .{ .offset = .zero, .duration = 0.1 },
        .{
            .offset = .xy(32, 0),
            .duration = 0.1,
            .extend = 1,
        },
    };
    const image = zhu.Image{ .size = .xy(64, 32) };

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Actor{ .action = .hoe });
    const sources = [_]zhu.Animation.Source{
        .{ .imageId = 1, .frames = &frames, .size = image.size },
        .{ .imageId = 1, .frames = &frames, .size = image.size },
        .{ .imageId = 1, .frames = &frames, .size = image.size },
        .{ .imageId = 1, .frames = &frames, .size = image.size },
        .{ .imageId = 1, .frames = &frames, .size = image.size },
    };
    world.add(entity, Animation.initSource(&sources));
    world.add(entity, Sprite{ .image = image });
    world.add(entity, Busy{});

    update(&world, 0.01);
    try std.testing.expect(!world.has(entity, UseFrame));

    update(&world, 0.11);

    try std.testing.expect(world.has(entity, UseFrame));
}
