const ecs = @import("ecs");
const zhu = @import("zhu");

const com = @import("../component.zig");
const ctx = @import("../context.zig");

pub fn update(reg: *ecs.World, _: f32) void {
    if (ctx.uiWantCaptureMouse) {
        ctx.hoveredEntity = null;
    } else {
        updateHoveredEntity(reg);
        updateSelectedEntity(reg);
    }
}

fn updateHoveredEntity(reg: *ecs.World) void {
    const mousePos = zhu.mouse.pos;

    // 统一以脚底向上 32 像素为中心，避开精灵帧 padding 差异。
    ctx.hoveredEntity = null;
    var maxY: f32 = -1e10;
    var view = reg.query(.{ com.Position, com.Sprite }).reverse();
    while (view.next()) |index| {
        if (reg.has(index, com.skill.Display)) continue;

        const pos = reg.get(index, com.Position).?;
        const center = pos.addY(-32);
        const rect: zhu.Rect = .init(center.sub(.xy(32, 32)), .xy(64, 64));

        if (rect.contains(mousePos) and pos.y > maxY) {
            maxY = pos.y;
            ctx.hoveredEntity = index;
        }
    }
}

fn updateSelectedEntity(reg: *ecs.World) void {
    if (ctx.selected != null) return;

    if (zhu.key.pressed(.MOUSE_LEFT)) {
        const entity = ctx.hoveredEntity orelse return;
        if (!reg.has(entity, com.Player)) return;
        ctx.selectedEntity = entity;
    } else if (zhu.key.pressed(.MOUSE_RIGHT)) {
        ctx.selectedEntity = null;
    }
}

pub fn draw(reg: *ecs.World) void {
    const entity = ctx.selectedEntity orelse return;
    const pos = reg.get(entity, com.Position).?;
    const range = reg.get(entity, com.Stats).?.range;
    const circle = zhu.getImage("circle.png").?;
    zhu.batch.drawImage(circle, pos.sub(.xy(range, range)), .{
        .size = .xy(range * 2, range * 2),
        .color = .rgba(0, 255, 0, 77),
    });
}
