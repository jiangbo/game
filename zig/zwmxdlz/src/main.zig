const std = @import("std");

const gfx = @import("graphics.zig");
const window = @import("window.zig");
const scene = @import("scene.zig");
const cache = @import("cache.zig");
const audio = @import("zaudio");

pub fn init() void {
    cache.init(allocator);
    audio.init(allocator);
    gfx.init(window.width, window.height);
    scene.init();
}

pub fn event(ev: *const window.Event) void {
    scene.currentScene.event(ev);
}

pub fn update() void {
    scene.currentScene.update();
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    scene.currentScene.render();
}

pub fn deinit() void {
    scene.deinit();
    cache.deinit();
    audio.deinit();
}

var allocator: std.mem.Allocator = undefined;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    allocator = gpa.allocator();
    window.width = 1280;
    window.height = 720;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    window.rand = prng.random();

    window.run(.{
        .title = "植物明星大乱斗",
        .init = init,
        .event = event,
        .update = update,
        .render = render,
        .deinit = deinit,
    });
}
