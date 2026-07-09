const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const map = @import("../map.zig");
const Clock = @import("../resource/Clock.zig");

const event = component.event;
const MapId = component.map.Id;
const Position = component.Position;
const Point = component.light.Point;
const Spot = component.light.Spot;
const Disabled = component.light.Disabled;
const Night = component.light.Night;
const Day = component.light.Day;
const Pending = component.light.Pending;

const Keyframe = struct { hour: f32, color: zhu.Color };

// 屏幕覆盖色关键帧：只做可见昼夜色调，不模拟真实光照。
const keyframes = [_]Keyframe{
    .{ .hour = 4, .color = .rgba(0.04, 0.06, 0.16, 0.42) },
    .{ .hour = 6, .color = .rgba(0.68, 0.30, 0.10, 0.18) },
    .{ .hour = 9, .color = .rgba(0, 0, 0, 0) },
    .{ .hour = 14, .color = .rgba(0, 0, 0, 0) },
    .{ .hour = 18, .color = .rgba(0.80, 0.32, 0.08, 0.22) },
    .{ .hour = 22, .color = .rgba(0.03, 0.05, 0.18, 0.48) },
    .{ .hour = 28, .color = .rgba(0.04, 0.06, 0.16, 0.42) },
};

var glowImage: zhu.Image = undefined;

pub fn init() void {
    glowImage = zhu.getImage("light.png").?;
}

pub fn update(world: *ecs.World) void {
    const clock = world.getPtr(world.entity, Clock).?;

    updatePending(world, clock.isDark());

    // 室内地图光源始终启用，不做时间切换
    if (!isOutdoor(map.current)) {
        world.clear(Disabled);
        return;
    }

    // 时间系统已经维护当前昼夜状态，这里只消费整点事件。
    if (world.getEvent(event.HourChanged).len == 0) return;

    world.clear(Disabled);
    if (clock.isDark()) {
        var query = world.query(.{Day});
        while (query.next()) |e| query.add(world, e, Disabled{});
    } else {
        var query = world.query(.{Night});
        while (query.next()) |e| query.add(world, e, Disabled{});
    }
}

fn updatePending(world: *ecs.World, dark: bool) void {
    // 新生成的灯光只同步一次初始昼夜状态。
    var query = world.query(.{Pending});
    while (query.next()) |entity| {
        const enabled = if (dark) world.has(entity, Night) //
            else world.has(entity, Day);
        if (enabled) world.remove(entity, Disabled);
    }
    world.clear(Pending);
}

pub fn draw(world: *ecs.World) void {
    const clock = world.getPtr(world.entity, Clock).?;

    drawOverlay(clock.hour, clock.minute);
    drawLights(world);
}

fn drawOverlay(hourValue: u8, minute: f32) void {
    if (!isOutdoor(map.current)) return;

    const hour = @as(f32, @floatFromInt(hourValue)) + minute / 60;
    const overlay = overlayAt(hour);
    if (overlay.a <= 0.001) return;

    zhu.batch.drawRect(zhu.camera.viewport(), .{ .color = overlay });
}

fn drawLights(world: *ecs.World) void {
    const allPoint = .{ Position, Point };
    var points = world.queryNot(allPoint, .{Disabled});
    while (points.next()) |entity| {
        const position = points.get(entity, Position);
        const point = points.get(entity, Point);
        const center = position.add(point.offset);
        const alpha = std.math.clamp(point.intensity, 0, 1);
        var color = point.color;
        color.a *= 0.68 * alpha;
        drawGlow(center, point.radius * 2.0, color);
    }

    const allSpot = .{ Position, Spot };
    // 第一版不做真实锥形，先退化成圆形占位光圈验证地图数据。
    var spots = world.queryNot(allSpot, .{Disabled});
    while (spots.next()) |entity| {
        const pos = spots.get(entity, Position);
        const spot = spots.get(entity, Spot);
        const alpha = std.math.clamp(spot.intensity, 0, 1);
        var color = spot.color;
        color.a *= 0.56 * alpha;
        drawGlow(pos, spot.radius * 1.6, color);
    }
}

fn overlayAt(hour: f32) zhu.Color {
    const sampleHour = if (hour < 4) hour + 24 else hour;

    var i: usize = 0;
    while (i + 1 < keyframes.len) : (i += 1) {
        const left = keyframes[i];
        const right = keyframes[i + 1];
        if (sampleHour >= left.hour and sampleHour < right.hour) {
            const t = smoothStep((sampleHour - left.hour) /
                (right.hour - left.hour));
            return left.color.mix(right.color, t);
        }
    }

    return keyframes[keyframes.len - 1].color;
}

fn isOutdoor(id: MapId) bool {
    // 光照系统只关心昼夜是否影响当前地图。
    return switch (id) {
        .town, .exterior => true,
        .school, .interior => false,
    };
}

fn drawGlow(center: zhu.Vector2, size: f32, color: zhu.Color) void {
    const position = center.add(.xy(-size * 0.5, -size * 0.5));
    zhu.batch.drawImage(glowImage, position, .{
        .size = .square(size),
        .color = color,
    });
}

fn smoothStep(value: f32) f32 {
    const t = std.math.clamp(value, 0, 1);
    return t * t * (3 - 2 * t);
}

test "light overlay 正午不改变画面" {
    const color = overlayAt(12);
    try std.testing.expectApproxEqAbs(0, color.a, 0.001);
}

test "light overlay 深夜比白天更明显" {
    const night = overlayAt(23);
    const noon = overlayAt(12);

    try std.testing.expect(night.a > noon.a);
    try std.testing.expect(night.b > night.r);
}

test "light update 夜晚启用夜灯禁用日灯" {
    map.current = .exterior; // 设置为室外地图
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    world.entity = world.createEntity();
    world.add(world.entity, Clock{});
    const clock = world.getPtr(world.entity, Clock).?;
    clock.hour = 18;

    const night = world.createEntity();
    world.add(night, Night{});
    world.add(night, Disabled{});

    const day = world.createEntity();
    world.add(day, Day{});

    world.addEvent(event.HourChanged{});

    update(&world);

    try std.testing.expect(!world.has(night, Disabled));
    try std.testing.expect(world.has(day, Disabled));
}

test "light update 白天启用日灯禁用夜灯" {
    map.current = .exterior; // 设置为室外地图
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    world.entity = world.createEntity();
    world.add(world.entity, Clock{ .hour = 12 });

    const night = world.createEntity();
    world.add(night, Night{});

    const day = world.createEntity();
    world.add(day, Day{});
    world.add(day, Disabled{});

    world.addEvent(event.HourChanged{});

    update(&world);

    try std.testing.expect(world.has(night, Disabled));
    try std.testing.expect(!world.has(day, Disabled));
}
