const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const camera = zhu.camera;

const title = @import("title.zig");
const world = @import("world.zig");

var isHelp = false;
var commandBuffer: [64]batch.Command = undefined;

const atlas: zhu.Atlas = @import("zon/atlas.zon");

const sceneType = enum { title, world };
var currentScene: sceneType = .title;

pub fn init(allocator: zhu.Allocator) void {
    zhu.text.init(@import("zon/font.zon"), .{ .size = 32 });
    zhu.loadAtlas(atlas, .nearest);
    batch.init(&commandBuffer);

    world.init(allocator);
    title.init();
}

pub fn deinit() void {
    world.deinit();
}

pub fn changeScene(newScene: sceneType) void {
    currentScene = newScene;
    switch (currentScene) {
        .title => title.enter(),
        .world => world.enter(),
    }
}

pub fn update(delta: f32) void {
    if (zhu.key.released(.H)) isHelp = !isHelp;
    zhu.extend.debug.toggle(.X);

    if (zhu.key.held(.LEFT_ALT) and zhu.key.released(.ENTER)) {
        return window.toggleFullScreen();
    }

    switch (currentScene) {
        .title => title.update(delta),
        .world => world.update(delta),
    }
}

pub fn draw() void {
    zhu.batch.beginDraw();
    zhu.batch.useTarget(.black, .{});
    defer zhu.batch.endDraw();

    switch (currentScene) {
        .title => title.draw(),
        .world => world.draw(),
    }
    if (isHelp) drawHelpInfo() else zhu.extend.debug.draw(.{});
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关闭
    ;
    debutTextCount = zhu.text.computeTextCount(text);
    zhu.text.draw(text, .xy(10, 10), .{ .color = .green });
}

var debutTextCount: usize = 0;
