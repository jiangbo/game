const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var soundBuffer: [20]zhu.audio.Sound = undefined;

pub fn init() void {
    zhu.audio.init(44100 / 2, &soundBuffer);
    scene.init();
}

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.draw();
}

pub fn deinit() void {
    scene.deinit();
    zhu.audio.deinit();
}

pub fn main() void {
    var allocator: std.mem.Allocator = undefined;
    var debugAllocator: std.heap.DebugAllocator(.{}) = undefined;
    if (builtin.mode == .Debug) {
        debugAllocator = std.heap.DebugAllocator(.{}).init;
        allocator = debugAllocator.allocator();
    } else {
        allocator = std.heap.c_allocator;
    }

    defer if (builtin.mode == .Debug) {
        _ = debugAllocator.deinit();
    };

    zhu.window.run(allocator, .{
        .title = "幽灵逃生",
        .logicSize = .{ .x = 1280, .y = 720 },
    });
}
