const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [128]zhu.batch.Command = undefined;
var soundBuffer: [40]zhu.audio.Sound = undefined;

pub fn init(allocator: zhu.Allocator) void {
    vertexBuffer = allocator.alloc(zhu.batch.Vertex, 5000);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    zhu.audio.init(44100, &soundBuffer);
    scene.init(allocator);
}

pub fn event(evt: *const zhu.window.Event) void {
    scene.handleEvent(evt);
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
    zhu.audio.deinit();
    allocator.free(vertexBuffer);
}

pub fn main(initInfo: std.process.Init) void {
    zhu.window.run(initInfo.io, initInfo.gpa, .{
        .title = "太空战机",
        .size = .xy(600, 800),
        .logicSize = .xy(600, 800),
        .scaleEnum = .fit,
    });
}
