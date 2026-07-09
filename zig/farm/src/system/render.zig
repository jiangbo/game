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

    const viewport = zhu.camera.viewport();
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
    return @intFromEnum(lhs.layer) < @intFromEnum(rhs.layer);
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

test "混合场景只绘制视口内精灵" {
    zhu.camera.init(.xy(640, 360));
    var vertices: [4]zhu.batch.Vertex = undefined;
    var commands: [16]zhu.batch.Command = undefined;
    zhu.batch.init(&vertices, &commands);
    zhu.batch.beginDraw();
    const vertexBuffer = &zhu.batch.vertices;

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const inside = world.createEntity();
    world.add(inside, Position.xy(50, 50));
    world.add(inside, Sprite{ .image = .{ .size = .xy(16, 16) } });
    world.add(inside, Render{});

    const outside = world.createEntity();
    world.add(outside, Position.xy(500, 500));
    world.add(outside, Sprite{ .image = .{ .size = .xy(16, 16) } });
    world.add(outside, Render{});

    draw(&world);

    try std.testing.expectEqual(1, vertexBuffer.items.len);
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
