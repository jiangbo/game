const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const text = zhu.text;

const com = @import("component.zig");
const spawn = @import("spawn.zig");
const ctx = @import("context.zig");
const map = @import("map.zig");

const ImageArea = struct {
    name: []const u8,
    image: [:0]const u8,
    rect: zhu.Rect,
};

const UiZon = struct {
    icon: []const ImageArea,
    border: []const ImageArea,
    face: []const ImageArea,
    padding: f32,
    frameSize: zhu.Vector2,
    fontOffset: zhu.Vector2,
};

const uiZon: UiZon = @import("zon/ui.zon");

var backgroundRect: zhu.Rect = undefined;
var hoveredIndex: ?u8 = null;
var scrollOffset: f32 = 0;

pub fn init() void {
    arrangeUnits();
}

pub fn arrangeUnits() void {
    // 计算背景条宽度和起始位置
    computeBackgroundRect(@floatFromInt(ctx.units.items.len));
    // 计算每个头像的位置
    computeUnitPositions();
    ctx.unitLayoutDirty = false;
}

fn computeBackgroundRect(count: f32) void {
    const padding = uiZon.padding;
    const size = uiZon.frameSize;

    const totalWidth = (size.x + padding) * count + padding;
    const maxScroll = @max(0, totalWidth - zhu.window.size.x);
    scrollOffset = @max(0, @min(scrollOffset, maxScroll));
    const startX = -scrollOffset;
    const startY = zhu.window.size.y - size.y - 2 * padding;

    backgroundRect = .{
        .min = .xy(startX, startY),
        .size = .xy(totalWidth, size.y + 2 * padding),
    };
}

fn computeUnitPositions() void {
    const padding = uiZon.padding;
    const size = uiZon.frameSize;
    const start = backgroundRect.min.addXY(padding, padding);
    for (ctx.units.items, 0..) |*unit, i| {
        const index: f32 = @floatFromInt(i);
        const offset = (size.x + padding) * index;
        unit.position = .xy(start.x + offset, start.y);
    }
}

pub fn deinit() void {}

fn updateScroll(delta: f32) void {
    const maxScroll = @max(0, backgroundRect.size.x - zhu.window.size.x);
    if (maxScroll == 0) {
        scrollOffset = 0;
        return;
    }

    const speed = 400 * delta;
    if (zhu.input.key.anyDown(&.{ .LEFT, .A })) scrollOffset += speed;
    if (zhu.input.key.anyDown(&.{ .RIGHT, .D })) scrollOffset -= speed;
    scrollOffset -= zhu.input.mouseScrollY * 30;
    scrollOffset = @max(0, @min(scrollOffset, maxScroll));

    computeBackgroundRect(@floatFromInt(ctx.units.items.len));
    computeUnitPositions();
}

pub fn update(delta: f32) void {
    if (ctx.unitLayoutDirty) arrangeUnits();
    updateScroll(delta);
    if (ctx.selected != null) return;
    if (ctx.uiWantCaptureMouse) {
        hoveredIndex = null;
        return;
    }

    const mousePos = zhu.window.mousePosition;

    for (ctx.units.items, 0..) |*unit, i| {
        const rect: zhu.Rect = .init(unit.position, uiZon.frameSize);
        if (rect.contains(mousePos)) {
            if (hoveredIndex == null or hoveredIndex.? != i) {
                zhu.audio.playSound("assets/audio/Fantasy_UI (1).ogg");
            }
            hoveredIndex = @intCast(i);
            break;
        }
    } else hoveredIndex = null;

    if (zhu.window.mouse.pressed(.LEFT)) {
        if (hoveredIndex) |idx| {
            if (ctx.cost >= ctx.units.items[idx].cost) {
                ctx.selected = idx;
                hoveredIndex = null;
            }
        }
    }
}

pub fn draw() void {
    // 背景条
    batch.drawRect(backgroundRect, .{ .color = .gray(0.1, 0.1) });

    for (ctx.units.items) |unit| {
        const class: u8 = @intFromEnum(unit.class);

        // 绘制头像
        const face = uiZon.face[unit.face];
        var image = zhu.assets.loadImage(face.image, .zero);
        batch.drawImage(image.sub(face.rect), unit.position, .{
            .size = uiZon.frameSize,
        });

        // 绘制边框
        const border = uiZon.border[if (unit.rarity > 1) 1 else 0];
        image = zhu.assets.loadImage(border.image, .zero);
        batch.drawImage(image.sub(border.rect), unit.position, .{
            .size = uiZon.frameSize,
        });

        // 绘制职业
        const icon = uiZon.icon[class];
        image = zhu.assets.loadImage(icon.image, .zero);
        batch.drawImage(image.sub(icon.rect), unit.position, .{
            .size = uiZon.frameSize.scale(0.5),
        });

        // 绘制消耗
        const pos = unit.position.add(uiZon.fontOffset);
        text.drawNumberColor(unit.cost, pos, .yellow);

        if (ctx.cost < unit.cost) {
            batch.drawRect(.init(unit.position, uiZon.frameSize), .{
                .color = .rgba(0, 0, 0, 0.2),
            });
        }
    }

    if (ctx.selectedUnit()) |unit| drawPrepare(unit.class);
}

/// 绘制准备出击单位（跟随鼠标）
fn drawPrepare(playerEnum: com.PlayerEnum) void {
    const template = &spawn.playerZon[@intFromEnum(playerEnum)];
    const mousePos = zhu.window.mousePosition;
    const found = map.findPlace(template.attackKind, mousePos);

    // 远程单位显示攻击范围
    if (template.attackKind == .ranged) {
        const range = template.stats.range;
        const diameter = range * 2;
        const circle = zhu.getImage("circle.png");
        zhu.batch.drawImage(circle, mousePos.sub(.xy(range, range)), .{
            .size = .xy(diameter, diameter),
            .color = .rgba(0, 1, 0, 0.2),
        });
    }

    // 绘制准备单位精灵（合法绿色，非法红色）
    const size = template.image.size;
    const image = zhu.assets.loadImage(template.image.path, size);
    const sub = image.sub(.init(.zero, template.size));
    zhu.batch.drawImage(sub, mousePos.add(template.offset), .{
        .color = if (found != null) .green else .red,
    });
}
