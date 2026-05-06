const std = @import("std");

const math = @import("math.zig");
const window = @import("window.zig");

const Vector2 = math.Vector2;

pub var modeEnum: enum { world, window } = .world;
pub var position: Vector2 = .zero;
pub var size: Vector2 = undefined;
pub var bound: Vector2 = undefined;

pub fn init() void {
    size = window.size;
    bound = window.size;
}

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

pub fn clampBound() void {
    const max = bound.sub(size).max(.zero);
    position.clamp(.zero, max);
}

pub fn directFollow(pos: Vector2) void {
    const halfWindowSize = size.scale(0.5);
    position = pos.sub(halfWindowSize);
    clampBound();
}

pub fn smoothFollow(pos: Vector2, smooth: f32) void {
    const target = pos.sub(size.scale(0.5));
    const distance = target.sub(position);

    const clampedSmooth = std.math.clamp(smooth, 0, 1);
    if (@abs(distance.x) < 1) position.x = target.x else {
        var moved = distance.x * clampedSmooth;
        if (@abs(moved) < 1) moved = math.ceilAway(moved);
        position.x += moved;
    }

    if (@abs(distance.y) < 1) position.y = target.y else {
        var moved = distance.y * clampedSmooth;
        if (@abs(moved) < 1) moved = math.ceilAway(moved);
        position.y += moved;
    }
    clampBound();
}
