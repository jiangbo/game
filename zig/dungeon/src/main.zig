const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [128]zhu.batch.Command = undefined;

pub fn init(allocator: zhu.Allocator) void {
    vertexBuffer = allocator.alloc(zhu.batch.Vertex, 5000);
    zhu.batch.init(vertexBuffer, &commandBuffer);

    zhu.batch.circleImage = zhu.assets.loadImage(
        "circle.png",
        .xy(128, 128),
    );
    const size = zhu.batch.circleImage.size;
    const rect = zhu.Rect.init(.zero, size).centerScale(0.25);
    zhu.batch.whiteImage = zhu.batch.circleImage.sub(rect);

    scene.init(allocator);
}

pub fn frame(delta: f32) void {
    scene.update(delta);

    zhu.batch.beginDraw();
    zhu.batch.useTarget(.black, .{});
    scene.draw();
    zhu.batch.endDraw();
}

pub fn deinit(allocator: zhu.Allocator) void {
    scene.deinit();
    allocator.free(vertexBuffer);
}

pub fn main(initInfo: std.process.Init) void {
    zhu.window.run(initInfo.io, initInfo.gpa, .{
        .title = "地宫探险",
        .size = .xy(1280, 800),
        .logicSize = .xy(640, 400),
        .scaleEnum = .fit,
    });
}
