const std = @import("std");

const cache = @import("cache.zig");
const window = @import("window.zig");
const math = @import("math.zig");
const gfx = @import("graphics.zig");
const audio = @import("audio.zig");
const scene = @import("scene.zig");
const http = @import("http.zig");

var soundBuffer: [10]audio.Sound = undefined;

fn init() callconv(.C) void {
    cache.init(allocator);
    gfx.init(window.size);
    audio.init(&soundBuffer);

    http.init(allocator);
    scene.init(allocator);
    timer = std.time.Timer.start() catch unreachable;
}

fn event(ev: ?*const window.Event) callconv(.C) void {
    if (ev) |e| scene.event(e);
}

fn frame() callconv(.C) void {
    const delta: f32 = @floatFromInt(timer.lap());
    scene.update(delta / std.time.ns_per_s);
    scene.render();
}

fn deinit() callconv(.C) void {
    scene.deinit();

    http.deinit();
    audio.deinit();
    gfx.deinit();
    cache.deinit();
}

var allocator: std.mem.Allocator = undefined;
var timer: std.time.Timer = undefined;

pub fn main() void {
    var debugAllocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debugAllocator.deinit();

    allocator = debugAllocator.allocator();
    window.size = .{ .x = 1280, .y = 720 };

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    math.rand = prng.random();

    window.run(.{
        .window_title = "哈基米大冒险",
        .width = @as(i32, @intFromFloat(window.size.x)),
        .height = @as(i32, @intFromFloat(window.size.y)),
        .high_dpi = false,
        .init_cb = init,
        .event_cb = event,
        .frame_cb = frame,
        .cleanup_cb = deinit,
    });
}
