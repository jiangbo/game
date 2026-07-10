const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var soundBuffer: [20]zhu.audio.Sound = undefined;

pub fn init(allocator: zhu.Allocator) void {
    zhu.audio.init(44100 / 2, &soundBuffer);
    scene.init(allocator);
}

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.draw();
}

pub fn deinit(allocator: zhu.Allocator) void {
    scene.deinit(allocator);
    zhu.audio.deinit();
}

pub fn main(initInfo: std.process.Init) void {
    zhu.window.run(initInfo.io, initInfo.gpa, .{
        .title = "幽灵逃生",
        .size = .xy(1280, 720),
        .logicSize = .{ .x = 1280, .y = 720 },
        .scaleEnum = .integer,
    });
}
