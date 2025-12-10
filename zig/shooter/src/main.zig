const std = @import("std");
const builtin = @import("builtin");
const zhu = @import("zhu");

const window = @import("zhu").window;
const scene = @import("scene.zig");

// pub extern "Imm32" fn ImmDisableIME(i32) std.os.windows.BOOL;

var soundBuffer: [40]zhu.audio.Sound = undefined;

pub fn init() void {
    zhu.audio.init(44100, &soundBuffer);
    scene.init();
}

pub fn event(evt: *const window.Event) void {
    scene.handleEvent(evt);
}

pub fn frame(delta: f32) void {
    scene.update(delta);
    scene.draw();
}

pub fn deinit() void {
    scene.deinit();
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

    // if (builtin.os.tag == .windows) {
    //     _ = ImmDisableIME(-1);
    // }

    window.run(allocator, .{
        .title = "太空战机",
        .logicSize = .{ .x = 600, .y = 800 },
    });
}
