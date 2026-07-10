const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [16]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;

const font: zhu.text.Font = @import("zon/font.zon");
const atlas: zhu.Atlas = @import("zon/atlas.zon");

pub fn init(allocator: zhu.Allocator) void {
    zhu.audio.init(44100 / 2, &soundBuffer);

    vertexBuffer = allocator.alloc(zhu.batch.Vertex, 5000);
    zhu.assets.loadAtlas(atlas);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    zhu.batch.circleImage = zhu.getImage("circle.png").?;
    const size = zhu.batch.circleImage.size;
    const rect = zhu.Rect.init(.zero, size).centerScale(0.25);
    zhu.batch.whiteImage = zhu.batch.circleImage.sub(rect);

    zhu.text.init(font);
    scene.init(allocator);
}

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.draw();
}

pub fn deinit(allocator: zhu.Allocator) void {
    scene.deinit(allocator);
    allocator.free(vertexBuffer);
    zhu.audio.deinit();
}

pub fn main(initInfo: std.process.Init) void {
    zhu.window.run(initInfo.io, initInfo.gpa, .{
        .title = "阳光岛",
        .size = .xy(1280, 720),
        .logicSize = .xy(640, 360),
        .scaleEnum = .integer,
    });
}
