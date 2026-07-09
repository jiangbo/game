const zhu = @import("zhu");

const input = @import("../input.zig");
const item = @import("item.zig");
const Inventory = @import("../resource/Inventory.zig");

const ImageId = zhu.graphics.ImageId;
const NineSource = zhu.NineImage.Source;

pub const Zon = struct {
    imageId: ImageId,
    position: zhu.Vector2,
    size: zhu.Vector2,
    slotSize: zhu.Vector2,
    slots: [10]zhu.Vector2,
    panel: NineSource,
    slot: NineSource,
    selected: NineSource,
};

pub const zon: Zon = @import("bar.zon");

var visible: bool = true;
pub var click: zhu.widget.Click = .empty;

pub fn reset() void {
    visible = true;
    click = .empty;
}

pub fn update(inv: *Inventory) void {
    if (input.pressed(.hotbar)) {
        visible = !visible;
        click = .empty;
    }

    if (input.hotbarPressed()) |index| inv.activeHotbar = index;

    if (!visible) return;

    if (click.update(hover())) |index| {
        inv.activeHotbar = index;
        zhu.audio.playSound("audio/UI_button08.ogg");
    }
    if (click.captured) input.mouseCaptured = true;
}

pub fn hover() ?usize {
    if (!visible) return null;

    const mouse = zhu.window.mouse.sub(zon.position);
    const slotRect = zhu.Rect.init(.zero, zon.slotSize);
    for (zon.slots, 0..) |offset, i| {
        if (slotRect.move(offset).contains(mouse)) return i;
    }
    return null;
}

pub fn draw(inv: *Inventory, hidden: ?usize) void {
    if (!visible) return;
    zhu.camera.push(.windowAt(zon.position));
    defer zhu.camera.pop();

    const atlas = zhu.assets.getImage(zon.imageId).?;
    const panelImage = zhu.NineImage.from(atlas, zon.panel);
    const slotImage = zhu.NineImage.from(atlas, zon.slot);
    const selectedImage = zhu.NineImage.from(atlas, zon.selected);

    // 绘制面板
    const panelRect = zhu.Rect.init(.zero, zon.size);
    zhu.batch.drawNine(panelImage, panelRect);

    for (zon.slots, 0..) |offset, i| {
        const rect = zhu.Rect.init(offset, zon.slotSize);
        // 绘制槽位
        zhu.batch.drawNine(slotImage, rect);

        if (i == inv.activeHotbar) {
            zhu.batch.drawNine(selectedImage, rect);
        }
    }

    for (inv.hotbar, zon.slots, 0..) |slotIndex, offset, i| {
        const rect = zhu.Rect.init(offset, zon.slotSize);
        const slotIndexValue = slotIndex orelse continue;
        const slot = inv.store.get(slotIndexValue) orelse continue;
        if (hidden) |index| if (index == i) continue;

        item.drawIcon(slot.item, rect.center());
    }

    for (inv.hotbar, zon.slots, 0..) |slotIndex, offset, i| {
        const rect = zhu.Rect.init(offset, zon.slotSize);
        const slotIndexValue = slotIndex orelse continue;
        const slot = inv.store.get(slotIndexValue) orelse continue;
        if (slot.count <= 1) continue;
        if (hidden) |index| if (index == i) continue;

        item.drawCount(slot.count, rect);
    }
}
