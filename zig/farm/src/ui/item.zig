const zhu = @import("zhu");

const component = @import("../component.zig");
const factory = @import("../factory.zig");

const ItemEnum = component.item.ItemEnum;
const NineSource = zhu.NineImage.Source;

pub const Tooltip = struct {
    imageId: zhu.graphics.ImageId,
    minSize: zhu.Vector2,
    offset: zhu.Vector2,
    padding: zhu.Vector2,
    spacing: f32,
    text: zhu.text.Option,
    panel: NineSource,
};

const tooltip: Tooltip = @import("tooltip.zon");

pub fn drawTooltip(itemType: ItemEnum) void {
    const item = factory.itemConfig(itemType);

    const option = tooltip.text;
    const categoryColor = zhu.Color.gray(0.2, 1).toSrgb();
    const categoryOption = option.with(.color, categoryColor);
    const lines = [_]zhu.text.Line{
        .{ .text = item.name, .option = option },
        .{ .text = item.category, .option = categoryOption },
        .{ .text = item.description, .option = option },
    };

    const size = zhu.text.measureLines(&lines, tooltip.spacing)
        .add(tooltip.padding.scale(2)).max(tooltip.minSize);
    // 判方向用最大宽度，避免描述长短变化导致 tooltip 左右跳。
    const position = zhu.widget.popupPosition(.{
        .anchor = zhu.window.mouse,
        .size = size,
        .maxSize = .{ .x = 200, .y = size.y },
        .offset = tooltip.offset,
    });

    zhu.camera.push(.window);
    defer zhu.camera.pop();

    const image = zhu.assets.getImage(tooltip.imageId).?;
    const panel = zhu.NineImage.from(image, tooltip.panel);
    zhu.batch.drawNine(panel, .init(position, size));

    const pos = position.add(tooltip.padding);
    zhu.text.drawLines(&lines, pos, tooltip.spacing);
}

pub fn drawIcon(itemType: ItemEnum, position: zhu.Vector2) void {
    const icon = factory.itemConfig(itemType).icon;
    zhu.batch.drawImage(factory.resolveImage(icon), position, .{
        .size = icon.size,
        .anchor = .center,
    });
}

pub fn drawCount(count: u32, rect: zhu.Rect) void {
    const pos = rect.max().sub(.square(1));
    zhu.text.drawFmt("{d}", .{count}, pos, .{ .anchor = .one });
}
