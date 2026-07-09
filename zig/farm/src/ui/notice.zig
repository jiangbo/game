const zhu = @import("zhu");
const ecs = @import("ecs");

const Notice = @import("../resource/Notice.zig");

const World = ecs.World;

var bubbleImage: zhu.NineImage = undefined;

pub fn init() void {
    const image = zhu.getImage("farm-rpg/UI/dialogue box.png").?;
    bubbleImage = zhu.NineImage.from(image, .{
        .rect = .init(.xy(0, 48), .xy(48, 48)),
        .patch = .{ .min = .xy(3, 4), .max = .xy(3, 3) },
    });
}

pub fn update(world: *World, delta: f32) void {
    const data = world.getPtr(world.entity, Notice).?;
    if (data.entry.timer <= 0) return;
    data.entry.timer -= delta;
}

pub fn draw(world: *World) void {
    const data = world.getPtr(world.entity, Notice).?;
    if (data.entry.timer <= 0) return;

    const option = zhu.text.Option{ .color = .black, .max = 168 };
    const textSize = zhu.text.measure(data.entry.text, option);
    const size = textSize.add(.xy(18, 14)).max(.xy(176, 40));
    const pos = zhu.window.size.sub(size).sub(.xy(12, 58));
    const rect: zhu.Rect = .init(pos, size);

    // 物品提示固定在快捷栏上方，和头顶世界提示区分开。
    zhu.batch.drawNine(bubbleImage, rect);
    zhu.text.draw(data.entry.text, rect.min.add(.xy(9, 7)), option);
}
