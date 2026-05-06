const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [16]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;

const font: zhu.text.BitMapFont = @import("zon/font.zon");
const atlas: zhu.Atlas = @import("zon/atlas.zon");

pub fn init() void {
    zhu.audio.init(44100 / 2, &soundBuffer);

    vertexBuffer = zhu.assets.oomAlloc(zhu.batch.Vertex, 5000);
    zhu.graphics.frameStats(true);
    zhu.assets.loadAtlas(atlas);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    const whiteCircle = zhu.getImage("circle.png");
    const area: zhu.Rect = .init(.xy(16, 16), .xy(32, 32));
    zhu.batch.whiteImage = whiteCircle.sub(area);

    const fontImage = zhu.getImage("font.png");
    zhu.text.initBitMapFont(fontImage, font, 16);
    scene.init();
}

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.draw();
}

pub fn deinit() void {
    scene.deinit();
    zhu.assets.free(vertexBuffer);
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
        .title = "阳光岛",
        .size = .xy(1280, 720),
        .logicSize = .xy(640, 360),
        .scaleEnum = .integer,
    });
}
