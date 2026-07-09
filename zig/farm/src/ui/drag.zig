const zhu = @import("zhu");

const factory = @import("../factory.zig");
const input = @import("../input.zig");
const Inventory = @import("../resource/Inventory.zig");
const item = @import("item.zig");
const bag = @import("bag.zig");
const bar = @import("bar.zig");

const Stack = Inventory.Stack;

const Source = union(enum) { bag: usize, bar: usize };
const Target = union(enum) { bag: usize, bar: usize };
const State = struct {
    source: Source,
    bagIndex: usize,
    item: Stack,
    start: zhu.Vector2,
    moved: bool = false,
};

const threshold2: f32 = 9;

var state: ?State = null;

pub fn reset() void {
    state = null;
}

pub fn update(inv: *Inventory) void {
    if (zhu.mouse.pressed(.LEFT)) start(inv);

    if (state) |*current| {
        input.mouseCaptured = true;
        const offset = zhu.window.mouse.sub(current.start);
        if (offset.length2() >= threshold2) current.moved = true;

        if (zhu.mouse.released(.LEFT)) finish(inv);
    }
}

pub fn active() bool {
    return state != null;
}

pub fn hiddenBag() ?usize {
    const current = state orelse return null;
    if (!current.moved) return null;
    return switch (current.source) {
        .bag => |source| source,
        .bar => null,
    };
}

pub fn hiddenBar() ?usize {
    const current = state orelse return null;
    if (!current.moved) return null;
    return switch (current.source) {
        .bar => |source| source,
        .bag => null,
    };
}

pub fn draw() void {
    const current = state orelse return;
    if (!current.moved) return;

    zhu.camera.push(.window);
    defer zhu.camera.pop();

    // 拖拽预览半透明，对齐 CPP UIDragPreview 的 0.6 alpha。
    const icon = factory.itemConfig(current.item.item).icon;
    zhu.batch.drawImage(factory.resolveImage(icon), zhu.window.mouse, .{
        .size = icon.size,
        .anchor = .center,
        .color = .{ .a = 0.6 },
    });

    if (current.item.count <= 1) return;

    const rect = zhu.Rect.init(
        zhu.window.mouse.sub(bag.zon.slotSize.scale(0.5)),
        bag.zon.slotSize,
    );
    item.drawCount(current.item.count, rect);
}

fn start(inv: *Inventory) void {
    state = null;

    if (bag.hover(inv.activePage)) |index| {
        const slot = inv.store.getPtr(index) orelse return;

        state = .{
            .source = .{ .bag = index },
            .bagIndex = index,
            .item = slot.*,
            .start = zhu.window.mouse,
        };
        return;
    }

    const barIndex = bar.hover() orelse return;
    const bagIndex = inv.hotbar[barIndex] orelse return;
    const slot = inv.store.getPtr(bagIndex) orelse return;

    state = .{
        .source = .{ .bar = barIndex },
        .bagIndex = bagIndex,
        .item = slot.*,
        .start = zhu.window.mouse,
    };
}

fn finish(inv: *Inventory) void {
    const current = state orelse return;
    state = null;

    if (!current.moved) return;

    // 松开鼠标后才改真实数据，避免拖拽中破坏库存不变量。
    switch (current.source) {
        .bag => |from| finishBag(inv, from),
        .bar => |from| finishBar(inv, from, current.bagIndex),
    }
}

fn finishBag(inv: *Inventory, from: usize) void {
    switch (target(inv) orelse return) {
        .bag => |to| _ = inv.move(from, to),
        .bar => |barIndex| inv.hotbarBind(barIndex, from),
    }
}

fn finishBar(inv: *Inventory, fromBar: usize, fromBag: usize) void {
    if (target(inv)) |to| switch (to) {
        .bag => |bagIndex| _ = inv.move(fromBag, bagIndex),
        .bar => |barIndex| inv.hotbarMove(fromBar, barIndex),
    } else inv.hotbar[fromBar] = null;
}

fn target(inv: *Inventory) ?Target {
    if (bag.hover(inv.activePage)) |i| return .{ .bag = i };
    if (bar.hover()) |index| return .{ .bar = index };
    return null;
}
