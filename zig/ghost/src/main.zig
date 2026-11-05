const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var soundBuffer: [20]zhu.audio.Sound = undefined;

pub fn init(allocator: zhu.Allocator) void {
    zhu.audio.init(&soundBuffer, .{ .sample_rate = 22050 });
    scene.init(allocator);
}

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.draw();
}

pub fn deinit(_: zhu.Allocator) void {
    scene.deinit();
    zhu.audio.deinit();
}

pub fn main(initInfo: std.process.Init) void {
    zhu.init(initInfo);
    zhu.extend.storage.init(initInfo, "ghost");
    zhu.window.run("幽灵逃生", .xy(1280, 720), .{
        .logicSize = .{ .x = 1280, .y = 720 },
        .scaleEnum = .integer,
    });
}
