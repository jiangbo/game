const std = @import("std");
const zhu = @import("zhu");

const Item = struct {
    position: zhu.Vector2, // 物品的位置
    direction: zhu.Vector2, // 物品的方向
    bounceCount: u8 = 3, // 物品反弹次数
};

var allocator: std.mem.Allocator = undefined;
var image: zhu.Image = undefined;
var size: zhu.Vector2 = undefined;
var bound: zhu.Rect = undefined; // 物品边界

pub var items: std.ArrayList(Item) = .empty;

pub fn init(allocator_: std.mem.Allocator) void {
    allocator = allocator_;
    image = zhu.getImage("image/bonus_life.png").?;
    size = image.size.scale(0.25);

    // 边界范围稍微大一点，等到物品全部看不见才消失。
    bound = .init(size.scale(-0.5), zhu.window.size.add(size));
}

pub fn maybeDropItem(position: zhu.Vector2) void {
    if (zhu.random.boolean()) return;

    const rad = zhu.random.float(0, std.math.tau);
    const dir: zhu.Vector2 = .xy(@cos(rad), @sin(rad));
    const item = Item{ .position = position, .direction = dir };
    items.append(allocator, item) catch @panic("item oom");
}

pub fn update(delta: f32) void {
    var iterator = std.mem.reverseIterator(items.items);
    while (iterator.nextPtr()) |item| {
        const offset = item.direction.scale(100 * delta);
        item.position = item.position.add(offset);

        if (item.bounceCount == 0) {
            if (!bound.contains(item.position)) {
                _ = items.swapRemove(iterator.index);
            }
            continue;
        }

        const x = item.position.x - size.x / 2;
        if (x < 0 or x > zhu.window.size.x - size.x) {
            item.direction.x = -item.direction.x;
            item.bounceCount -|= 1;
        }

        const y = item.position.y - size.y / 2;
        if (y < 0 or y > zhu.window.size.y - size.y) {
            item.direction.y = -item.direction.y;
            item.bounceCount -|= 1;
        }
    }
}

pub fn draw() void {
    for (items.items) |item| {
        // 将锚点定位到物品的中心。
        zhu.batch.drawImage(image, item.position, .{
            .size = size,
            .anchor = .center,
        });
    }
}

pub fn deinit() void {
    items.deinit(allocator);
}
