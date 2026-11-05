const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var commandBuffer: [128]zhu.batch.Command = undefined;
var soundBuffer: [40]zhu.audio.Sound = undefined;

pub fn init(allocator: zhu.Allocator) void {
    zhu.loadAtlas(@import("zon/atlas.zon"), .nearest);
    zhu.batch.init(&commandBuffer);
    zhu.audio.init(&soundBuffer, .{});
    scene.init(allocator);
}

pub fn event(evt: *const zhu.window.Event) void {
    scene.handleEvent(evt);
}

pub fn frame(delta: f32) void {
    scene.update(delta);

    zhu.batch.beginDraw(.black, .{});
    scene.draw();
    zhu.batch.endDraw();
}

pub fn deinit(_: zhu.Allocator) void {
    scene.deinit();
    zhu.audio.deinit();
}

pub fn main(initInfo: std.process.Init) void {
    zhu.init(initInfo);
    zhu.extend.storage.init(initInfo, "shooter");
    zhu.window.run("太空战机", .xy(600, 800), .{
        .logicSize = .xy(600, 800),
        .scaleEnum = .fit,
    });
}
