const std = @import("std");

const cache = @import("cache.zig");
const window = @import("window.zig");
const gfx = @import("graphics.zig");
const audio = @import("audio.zig");
const scene = @import("scene.zig");

var soundBuffer: [10]audio.Sound = undefined;

pub fn init() void {
    cache.init(allocator);
    gfx.init(window.width, window.height);
    audio.init(&soundBuffer);

    scene.init();
}

pub fn event(ev: *const window.Event) void {
    scene.event(ev);
}

pub fn update() void {
    scene.update();
}

pub fn render() void {
    scene.render();
}

pub fn deinit() void {
    scene.deinit();
    audio.deinit();
    cache.deinit();
}

var allocator: std.mem.Allocator = undefined;

pub fn main() void {
    var debugAllocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debugAllocator.deinit();

    allocator = debugAllocator.allocator();
    window.width = 1280;
    window.height = 720;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    window.rand = prng.random();

    window.run(.{
        .title = "空洞武士",
        .init = init,
        .event = event,
        .update = update,
        .render = render,
        .deinit = deinit,
    });
}
