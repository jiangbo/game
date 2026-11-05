const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var commandBuffer: [16]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;

const font: zhu.text.static.Font = @import("zon/font.zon");
const atlas: zhu.Atlas = @import("zon/atlas.zon");

pub fn init(allocator: zhu.Allocator) void {
    zhu.audio.init(&soundBuffer, .{ .sample_rate = 22050 });
    zhu.loadAtlas(atlas, .nearest);
    zhu.batch.init(&commandBuffer);
    zhu.text.init(font, .{});
    zhu.camera.roundPosition = true;
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
    zhu.init(initInfo);
    zhu.extend.storage.init(initInfo, "sunny");
    zhu.window.run("阳光岛", .xy(1280, 720), .{
        .logicSize = .xy(640, 360),
        .scaleEnum = .integer,
    });
}
