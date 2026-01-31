const std = @import("std");

const math = @import("math.zig");
const window = @import("window.zig");

const Vector2 = math.Vector2;

pub var modeEnum: enum { world, window } = .world;
pub var position: Vector2 = .zero;
pub var bound: Vector2 = undefined;

pub fn toWorld(windowPosition: Vector2) Vector2 {
    return windowPosition.add(position);
}

pub fn toWindow(worldPosition: Vector2) Vector2 {
    return worldPosition.sub(position);
}

pub fn control(distance: f32) void {
    if (window.isKeyDown(.UP)) position.y -= distance;
    if (window.isKeyDown(.DOWN)) position.y += distance;
    if (window.isKeyDown(.LEFT)) position.x -= distance;
    if (window.isKeyDown(.RIGHT)) position.x += distance;
}

pub fn directFollow(pos: Vector2) void {
    // const scaleSize = window.size.div(scale);
    // const half = scaleSize.scale(0.5);
    const halfWindowSize = window.size.scale(0.5);
    const max = bound.sub(window.size).max(.zero);
    position = pos.sub(halfWindowSize);
    position.clamp(.zero, max);
}
