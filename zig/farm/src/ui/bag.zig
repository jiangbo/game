const std = @import("std");
const zhu = @import("zhu");

const input = @import("../input.zig");
const item = @import("item.zig");
const Inventory = @import("../resource/Inventory.zig");

const ImageId = zhu.graphics.ImageId;
const NineSource = zhu.NineImage.Source;

const Hover = union(enum) { body, slot: usize, prev, next, close };

pub const Zon = struct {
    const Button = struct {
        rect: zhu.Rect,
        normal: zhu.Rect,
        pressed: zhu.Rect,
    };

    imageId: ImageId,
    buttonImageId: ImageId,
    position: zhu.Vector2,
    size: zhu.Vector2,
    pageCount: usize,
    slotSize: zhu.Vector2,
    slots: [20]zhu.Vector2,
    prev: Button,
    next: Button,
    pageText: zhu.Vector2,
    close: Button,
    panel: NineSource,
    slot: NineSource,
};

pub const zon: Zon = @import("bag.zon");
const pageSize = zon.slots.len;

var position: zhu.Vector2 = zon.position;
pub var closed: bool = true;
pub var click: zhu.widget.ClickT(Hover) = .empty;
pub var drag: ?zhu.Vector2 = null;

pub fn reset() void {
    position = zon.position;
    closed = true;
    click = .empty;
    drag = null;
}

pub fn update(inv: *Inventory) bool {
    if (input.pressed(.inventory)) closed = !closed;
    if (closed) {
        const captured = drag != null;
        click, drag = .{ .empty, null };
        if (captured) input.mouseCaptured = true;
        return captured;
    }
    if (updatePanelDrag()) return true;

    const clicked = click.update(hovered()) orelse {
        if (click.captured) input.mouseCaptured = true;
        return click.captured;
    };
    const max = zon.pageCount - 1;
    switch (clicked) {
        .prev => inv.activePage -|= 1,
        .next => inv.activePage = @min(inv.activePage + 1, max),
        .close => {
            closed, click, drag = .{ true, .empty, null };
        },
        .body, .slot => {},
    }

    input.mouseCaptured = true;
    return true;
}

pub fn hover(page: usize) ?usize {
    if (closed) return null;

    return switch (hovered() orelse return null) {
        .slot => |index| page * pageSize + index,
        .body, .prev, .next, .close => null,
    };
}

pub fn draw(inv: *Inventory, hidden: ?usize) void {
    if (closed) return;
    zhu.camera.push(.windowAt(position));
    defer zhu.camera.pop();

    const atlas = zhu.assets.getImage(zon.imageId).?;
    const buttonImage = zhu.assets.getImage(zon.buttonImageId).?;
    const panelImage = zhu.NineImage.from(atlas, zon.panel);
    const slotImage = zhu.NineImage.from(atlas, zon.slot);

    const panelRect = zhu.Rect.init(.zero, zon.size);
    zhu.batch.drawNine(panelImage, panelRect);

    const first = inv.activePage * pageSize;
    for (zon.slots) |offset| {
        const slotRect = zhu.Rect.init(offset, zon.slotSize);
        zhu.batch.drawNine(slotImage, slotRect);
    }

    for (zon.slots, 0..) |offset, i| {
        const bagIndex = first + i;
        const slotRect = zhu.Rect.init(offset, zon.slotSize);
        const slot = inv.store.get(bagIndex) orelse continue;
        if (hidden) |index| if (index == bagIndex) continue;

        item.drawIcon(slot.item, slotRect.center());
    }

    for (zon.slots, 0..) |offset, i| {
        const bagIndex = first + i;
        const slotRect = zhu.Rect.init(offset, zon.slotSize);
        const slot = inv.store.get(bagIndex) orelse continue;
        if (slot.count <= 1) continue;
        if (hidden) |index| if (index == bagIndex) continue;

        item.drawCount(slot.count, slotRect);
    }

    drawButton(buttonImage, zon.prev, .prev);
    drawButton(buttonImage, zon.next, .next);
    drawButton(buttonImage, zon.close, .close);

    const args = .{ inv.activePage + 1, zon.pageCount };
    zhu.text.drawFmt("{d}/{d}", args, zon.pageText, .{
        .anchor = .center,
        .color = .black,
    });
}

fn updatePanelDrag() bool {
    if (drag) |offset| {
        input.mouseCaptured = true;
        if (zhu.mouse.released(.LEFT)) drag = null else {
            position = zhu.window.mouse.sub(offset);
        }
        return true;
    }

    if (!zhu.mouse.pressed(.LEFT)) return false;
    if (!std.meta.eql(hovered(), .body)) return false;

    input.mouseCaptured = true;
    drag = zhu.window.mouse.sub(position);
    click = .empty;
    return true;
}

fn hovered() ?Hover {
    const mouse = zhu.window.mouse.sub(position);
    if (zon.close.rect.contains(mouse)) return .close;

    const bagRect = zhu.Rect.init(.zero, zon.size);
    if (!bagRect.contains(mouse)) return null;

    const slotRect = zhu.Rect.init(.zero, zon.slotSize);
    for (zon.slots, 0..) |offset, i| {
        const rect = slotRect.move(offset);
        if (rect.contains(mouse)) return .{ .slot = i };
    }

    if (zon.prev.rect.contains(mouse)) return .prev;
    if (zon.next.rect.contains(mouse)) return .next;
    return .body;
}

fn drawButton(image: zhu.Image, button: Zon.Button, target: Hover) void {
    var pressed = false;
    if (click.pressed) |p| pressed = std.meta.eql(p, target);

    const source = if (pressed) button.pressed else button.normal;
    zhu.batch.drawImage(image.sub(source), button.rect.min, .{
        .size = button.rect.size,
    });
}
