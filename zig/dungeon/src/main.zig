const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

// 顶点由引擎管理，游戏只提供绘制命令缓冲。
var commandBuffer: [128]zhu.batch.Command = undefined;

// 初始化基础图形和场景，图片尺寸用于异步加载校验。
pub fn init(allocator: zhu.Allocator) void {
    _ = zhu.loadImage("circle.png", .all(128), .{});
    zhu.batch.init(&commandBuffer);

    scene.init(allocator);
}

pub fn frame(delta: f32) void {
    scene.update(delta);

    zhu.batch.beginDraw(.black, .{});
    scene.draw();
    zhu.batch.endDraw();
}

pub fn deinit(_: zhu.Allocator) void {
    scene.deinit();
}

// 先设置引擎分配器和 IO，再创建窗口。
pub fn main(initInfo: std.process.Init) void {
    zhu.init(initInfo);
    zhu.window.run("地宫探险", .xy(1280, 800), .{
        .logicSize = .xy(640, 400),
        .scaleEnum = .fit,
    });
}
