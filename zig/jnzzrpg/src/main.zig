const std = @import("std");

const window = @import("window.zig");
const audio = @import("audio.zig");
const scene = @import("scene.zig");

var soundBuffer: [20]audio.Sound = undefined;

pub extern "Imm32" fn ImmDisableIME(i32) std.os.windows.BOOL;

pub fn init() void {
    audio.init(44100 / 4, &soundBuffer);
    scene.init();
}

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.render();
}

pub fn deinit() void {
    audio.deinit();
}

pub fn main() void {
    var allocator: std.mem.Allocator = undefined;
    var debugAllocator: std.heap.DebugAllocator(.{}) = undefined;
    if (@import("builtin").mode == .Debug) {
        debugAllocator = std.heap.DebugAllocator(.{}).init;
        allocator = debugAllocator.allocator();
    } else {
        allocator = std.heap.c_allocator;
    }

    defer if (@import("builtin").mode == .Debug) {
        _ = debugAllocator.deinit();
    };

    _ = ImmDisableIME(-1);

    const Font = struct { lineHeight: i32, chars: []const window.Char };

    const font: Font = @import("font.zon");
    window.lineHeight = font.lineHeight;

    window.run(allocator, .{
        .title = "教你制作RPG游戏",
        .size = .{ .x = 800, .y = 600 },
        .chars = font.chars,
    });
}
