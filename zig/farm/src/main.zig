const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [64]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;
var debug = false;

pub fn init(allocator: zhu.Allocator) void {
    vertexBuffer = allocator.alloc(zhu.batch.Vertex, 4096);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    zhu.audio.init(44100 / 2, &soundBuffer);
    zhu.assets.loadAtlas(@import("zon/atlas.zon"));

    zhu.batch.circleImage = zhu.getImage("circle.png").?;
    const size = zhu.batch.circleImage.size;
    const rect = zhu.Rect.init(.zero, size).centerScale(0.25);
    zhu.batch.whiteImage = zhu.batch.circleImage.sub(rect);

    var font: zhu.text.Font = @import("zon/font.zon");
    font.lineHeight += 2;
    zhu.text.init(font);

    zhu.window.useWindowIcon("icon.ico");
    zhu.window.useCursor("cursor.png", .{});

    scene.init(allocator);
}

pub fn frame(delta: f32) void {
    if (zhu.key.released(.X)) debug = !debug;

    scene.update(delta);

    zhu.batch.beginDraw();
    scene.draw();
    if (debug) drawDebug();
    zhu.batch.endDraw();
}

fn drawDebug() void {
    const total = scene.world.entities.versions.items.len;

    var entityBuffer: [32]u8 = undefined;
    var componentBuffer: [32]u8 = undefined;
    const rows = [_]zhu.debug.Row{.{
        .label = "世界",
        .left = zhu.format(&entityBuffer, "实体 {}/{}", .{
            total - scene.world.entities.deletedCount,
            total,
        }),
        .right = zhu.format(&componentBuffer, "组件 {}", .{
            scene.world.map.count(),
        }),
    }};
    zhu.debug.draw(&rows);
}

pub fn deinit(allocator: zhu.Allocator) void {
    scene.deinit();
    zhu.audio.deinit();
    allocator.free(vertexBuffer);
}

pub fn main(initInfo: std.process.Init) void {
    zhu.window.run(initInfo.io, initInfo.gpa, .{
        .title = "迷你农场",
        .size = .xy(1280, 720),
        .logicSize = .xy(640, 360),
        .scaleEnum = .fit,
    });
}

test {
    std.testing.refAllDecls(scene);
}
