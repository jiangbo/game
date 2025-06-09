const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const camera = @import("camera.zig");

const titleScene = @import("scene/title.zig");
const worldScene = @import("scene/world.zig");
const battleScene = @import("scene/battle.zig");

const SceneType = enum { title, world, battle };
var currentSceneType: SceneType = .title;

const SIZE: gfx.Vector = .init(1000, 800);
pub var cursor: gfx.Texture = undefined;
var cursorTexture: gfx.Texture = undefined;

const MAX_COUNT = 100;

var vertexBuffer: [MAX_COUNT * 4]camera.Vertex = undefined;
var indexBuffer: [MAX_COUNT * 6]u16 = undefined;

var texture: gfx.Texture = undefined;

pub fn init() void {
    var index: u16 = 0;
    while (index < MAX_COUNT) : (index += 1) {
        indexBuffer[index * 6 + 0] = index * 4 + 0;
        indexBuffer[index * 6 + 1] = index * 4 + 1;
        indexBuffer[index * 6 + 2] = index * 4 + 2;
        indexBuffer[index * 6 + 3] = index * 4 + 0;
        indexBuffer[index * 6 + 4] = index * 4 + 2;
        indexBuffer[index * 6 + 5] = index * 4 + 3;
    }
    camera.init(.init(.zero, window.size), SIZE, &vertexBuffer, &indexBuffer);

    titleScene.init();
    worldScene.init();
    battleScene.init();
    window.showCursor(false);
    cursorTexture = gfx.loadTexture("assets/mc_1.png", .init(32, 32));
    texture = gfx.loadTexture("assets/fight/p1.png", .init(960, 240));
    cursor = cursorTexture;
    window.fontTexture = gfx.loadTexture("assets/4_0.png", .init(256, 256));

    enter();
}

pub fn enter() void {
    sceneCall("enter", .{});
}

pub fn exit() void {
    sceneCall("exit", .{});
}

pub fn changeNextScene() void {
    const next: usize = @intFromEnum(currentSceneType);
    const len = std.enums.values(SceneType).len;
    changeScene(@enumFromInt((next + 1) % len));
}

pub fn changeScene(sceneType: SceneType) void {
    exit();
    currentSceneType = sceneType;
    enter();
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.X)) camera.debug = !camera.debug;
    cursor = cursorTexture;
    sceneCall("update", .{delta});
}

pub fn render() void {
    camera.beginDraw(.{ .a = 1 });
    defer camera.endDraw();

    sceneCall("render", .{});
    camera.draw(cursor, window.mousePosition.add(camera.rect.min));
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => window.call(titleScene, function, args),
        .world => window.call(worldScene, function, args),
        .battle => window.call(battleScene, function, args),
    }
}
