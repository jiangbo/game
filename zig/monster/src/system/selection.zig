const zhu = @import("zhu");

const com = @import("../component.zig");
const ctx = @import("../context.zig");

var currentRangeEntity: ?zhu.ecs.Entity = null;

pub fn update(reg: *zhu.ecs.Registry, _: f32) void {
    if (ctx.uiWantCaptureMouse) {
        ctx.hoveredEntity = null;
    } else {
        updateHoveredEntity(reg);
        updateSelectedEntity(reg);
    }

    updateShowRange(reg);
}

fn updateHoveredEntity(reg: *zhu.ecs.Registry) void {
    const mousePos = zhu.window.mousePosition;

    // 统一以脚底向上 32 像素为中心，避开精灵帧 padding 差异。
    ctx.hoveredEntity = null;
    var maxY: f32 = -1e10;
    var view = reg.view(.{ com.Position, com.Sprite });
    while (view.next()) |index| {
        if (view.has(index, com.skill.Display)) continue;

        const pos = view.get(index, com.Position);
        const center = pos.addY(-32);
        const rect: zhu.Rect = .init(center.sub(.xy(32, 32)), .xy(64, 64));

        if (rect.contains(mousePos) and pos.y > maxY) {
            maxY = pos.y;
            ctx.hoveredEntity = view.toEntity(index);
        }
    }
}

fn updateSelectedEntity(reg: *zhu.ecs.Registry) void {
    if (ctx.selected != null) return;

    if (zhu.window.mouse.pressed(.LEFT)) {
        const entity = ctx.hoveredEntity orelse return;
        if (!reg.has(entity, com.Player)) return;
        ctx.selectedEntity = entity;
    } else if (zhu.window.mouse.pressed(.RIGHT)) {
        ctx.selectedEntity = null;
    }
}

fn updateShowRange(reg: *zhu.ecs.Registry) void {
    if (currentRangeEntity) |entity| {
        const selected = ctx.selectedEntity;
        if (!reg.validEntity(entity) or
            selected == null or
            selected.?.index != entity.index or
            selected.?.version != entity.version)
        {
            reg.remove(entity, com.ShowRange);
            currentRangeEntity = null;
        }
    }

    const selected = ctx.selectedEntity orelse return;
    if (!reg.validEntity(selected)) {
        ctx.selectedEntity = null;
        return;
    }
    if (!reg.has(selected, com.Player)) return;
    if (!reg.has(selected, com.Stats)) return;

    reg.add(selected, com.ShowRange{});
    currentRangeEntity = selected;
}

pub fn draw(reg: *zhu.ecs.Registry) void {
    drawRange(reg);
}

fn drawRange(reg: *zhu.ecs.Registry) void {
    var view = reg.view(.{ com.ShowRange, com.Position, com.Stats });
    while (view.next()) |entity| {
        const pos = view.get(entity, com.Position);
        const r = view.get(entity, com.Stats).range;
        const circle = zhu.getImage("circle.png");
        zhu.batch.drawImage(circle, pos.sub(.xy(r, r)), .{
            .size = .xy(r * 2, r * 2),
            .color = .rgba(0, 1, 0, 0.3),
        });
    }
}
