const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const Position = component.Position;
const Render = component.render.Render;
const Sprite = component.render.Sprite;
const YSort = component.render.YSort;
const Hidden = component.render.Hidden;

pub fn update(world: *ecs.World) void {
    var query = world.query(.{ Render, Position, YSort });
    while (query.next()) |entity| {
        const position = query.get(entity, Position);
        query.getPtr(entity, Render).depth = position.y;
    }
}

pub fn draw(world: *ecs.World) void {
    world.sort(Render, lessThan);

    const viewport = zhu.camera.mainWorldRect();
    var query = world.queryBy(Render, .{ Position, Sprite }, .{Hidden});
    while (query.next()) |entity| {
        const render = query.get(entity, Render);
        const position = query.get(entity, Position);
        const sprite = query.get(entity, Sprite);

        const spriteSize = sprite.size orelse sprite.image.size;
        const spritePosition = position.add(sprite.offset);
        const spriteRect = zhu.Rect.init(spritePosition, spriteSize);
        if (!viewport.intersect(spriteRect)) continue;
        zhu.batch.drawImage(sprite.image, position.add(sprite.offset), .{
            .size = sprite.size,
            .color = render.color,
            .uvRect = sprite.image.uvFlip(sprite.flip, false),
        });
    }
}

pub fn lessThan(lhs: Render, rhs: Render) bool {
    if (lhs.layer == rhs.layer) return lhs.depth < rhs.depth;
    return @backingInt(lhs.layer) < @backingInt(rhs.layer);
}

test "渲染排序先比较图层再比较深度" {
    const ground = Render{ .layer = .ground, .depth = 100 };
    const crop = Render{ .layer = .crop, .depth = 0 };
    const actorBack = Render{ .layer = .actor, .depth = 8 };
    const actorFront = Render{ .layer = .actor, .depth = 16 };

    try std.testing.expect(lessThan(ground, crop));
    try std.testing.expect(lessThan(actorBack, actorFront));
    try std.testing.expect(!lessThan(actorFront, actorBack));
}

test "YSort 会把位置 y 写入渲染深度" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 42));
    world.add(entity, Render{});
    world.add(entity, YSort{});

    update(&world);

    const renders = world.get(entity, Render).?;
    try std.testing.expectEqual(42, renders.depth);
}
