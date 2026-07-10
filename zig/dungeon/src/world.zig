const std = @import("std");
const ecs = @import("ecs");

const component = @import("component.zig");

pub var world: ecs.World = undefined;
pub var turn: component.TurnState = .player;

pub fn init(allocator: std.mem.Allocator) void {
    world = .init(allocator);
    turn = .player;
}

pub fn reset() void {
    world.reset();
    turn = .player;
}

pub fn deinit() void {
    world.deinit();
}
