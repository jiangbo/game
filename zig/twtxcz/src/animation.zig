const std = @import("std");
const gfx = @import("graphics.zig");
const cache = @import("cache.zig");

pub const FixedSizeFrameAnimation = struct {
    interval: f32,
    current: u32 = 0,
    timer: f32 = 0,
    frames: [maxFrame]gfx.Texture,

    const maxFrame = 6;

    pub fn load(comptime pathFmt: []const u8, interval: f32) ?@This() {
        var self = @This(){ .frames = undefined, .interval = interval };
        var buffer: [64]u8 = undefined;
        for (0..maxFrame) |index| {
            const path = std.fmt.bufPrintZ(&buffer, pathFmt, .{index}) catch |e| {
                std.log.warn("frame animation path error: {}", .{e});
                return null;
            };

            const texture = cache.TextureCache.load(path);
            self.frames[index] = texture orelse return null;
        }

        return self;
    }

    pub fn play(self: *@This(), delta: f32) void {
        self.timer += delta;
        if (self.timer >= self.interval) {
            self.current = (self.current + 1) % @as(u32, @intCast(self.frames.len));
            self.timer = 0;
        }
    }

    pub fn currentTexture(self: @This()) gfx.Texture {
        return self.frames[self.current];
    }
};

pub const FrameAnimation = struct {
    left: FixedSizeFrameAnimation,
    right: FixedSizeFrameAnimation,
};
