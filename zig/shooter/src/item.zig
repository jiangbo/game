const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const camera = zhu.camera;
const window = zhu.window;

const Item = struct {
    position: gfx.Vector, // 物品的位置
    direction: gfx.Vector, // 物品的方向
    bounceCount: u8 = 3, // 物品反弹次数
};

const SPEED = 100;

var texture: gfx.Texture = undefined;
var size: gfx.Vector = undefined;
var bound: gfx.Rect = undefined; // 物品边界

pub var items: std.ArrayList(Item) = .empty;

pub fn init() void {
    texture = gfx.loadTexture("assets/image/bonus_life.png", .init(87, 87));
    size = texture.size().scale(0.25);

    // 边界范围稍微大一点，等到物品全部看不见才消失。
    bound = .init(size.scale(-0.5), window.logicSize.add(size));
}

pub fn maybeDropItem(position: gfx.Vector) void {
    if (zhu.randomBool()) return; // 先设置百分之五十几率掉落

    const rad = zhu.randomF32(0, std.math.tau);
    const dir: gfx.Vector = .init(@cos(rad), @sin(rad));
    const item = Item{ .position = position, .direction = dir };
    items.append(window.allocator, item) catch @panic("item oom");
}

pub fn update(delta: f32) void {
    var iterator = std.mem.reverseIterator(items.items);
    while (iterator.nextPtr()) |item| {
        // 移动物品
        const offset = item.direction.scale(SPEED * delta);
        item.position = item.position.add(offset);

        if (item.bounceCount == 0) {
            // bounceCount 到 0 直接消失，感觉没有完全走出屏幕。
            if (!bound.contains(item.position)) {
                // 物品超过边界才消失
                _ = items.swapRemove(iterator.index);
            }
            continue;
        }
        // X 轴移动反向
        const x = item.position.x - size.x / 2;
        if (x < 0 or x > window.logicSize.x - size.x) {
            item.direction.x = -item.direction.x;
            item.bounceCount -|= 1;
        }
        // Y 轴移动反向
        const y = item.position.y - size.y / 2;
        if (y < 0 or y > window.logicSize.y - size.y) {
            item.direction.y = -item.direction.y;
            item.bounceCount -|= 1;
        }
    }
}

pub fn draw() void {
    for (items.items) |item| {
        // 将锚点定位到物品的中心
        camera.drawOption(texture, item.position, .{
            .size = size,
            .anchor = .center,
        });
    }
}
