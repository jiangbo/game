const std = @import("std");

const window = @import("window.zig");
const cache = @import("cache.zig");
const math = @import("math.zig");
const Texture = @import("gpu.zig").Texture;

const Anchor = enum {
    topLeft,
    topCenter,
    topRight,
    centerLeft,
    centerCenter,
    centerRight,
    bottomLeft,
    bottomCenter,
    bottomRight,
};

pub const FrameAnimation = SliceFrameAnimation;

pub const SliceFrameAnimation = struct {
    timer: window.Timer,
    index: usize = 0,
    loop: bool = true,
    anchor: Anchor = .bottomCenter,

    textures: []const Texture,

    pub fn init(textures: []const Texture) SliceFrameAnimation {
        return .{ .textures = textures, .timer = .init(0.1) };
    }

    pub fn load(comptime pathFmt: []const u8, max: u8) SliceFrameAnimation {
        const textures = cache.TextureSlice.load(pathFmt, 1, max);
        return .init(textures);
    }

    pub fn update(self: *@This(), delta: f32) void {
        if (self.timer.isRunningAfterUpdate(delta)) return;

        if (self.index == self.textures.len - 1) {
            if (self.loop) self.reset();
        } else {
            self.timer.reset();
            self.index += 1;
        }
    }

    pub fn reset(self: *@This()) void {
        self.timer.reset();
        self.index = 0;
    }

    pub fn finished(self: *const @This()) bool {
        return self.timer.finished and !self.loop;
    }
};

pub const AtlasFrameAnimation = struct {
    timer: window.Timer,
    index: usize = 0,
    loop: bool = true,
    texture: Texture,
    frames: []const math.Rectangle,
    anchor: Anchor = .bottomCenter,

    pub fn init(texture: Texture, frames: []const math.Rectangle) AtlasFrameAnimation {
        return .{ .texture = texture, .frames = frames, .timer = .init(0.1) };
    }

    pub fn load(path: [:0]const u8, count: u8) AtlasFrameAnimation {
        const texture = cache.Texture.load(path);

        const frames = cache.RectangleSlice.load(path, count);

        const width = @divExact(texture.width(), @as(f32, @floatFromInt(frames.len)));
        var rect: math.Rectangle = .{ .w = width, .h = texture.height() };

        for (0..frames.len) |index| {
            rect.x = @as(f32, @floatFromInt(index)) * width;
            frames[index] = rect;
        }

        return .init(texture, frames);
    }

    pub fn update(self: *@This(), delta: f32) void {
        if (self.timer.isRunningAfterUpdate(delta)) return;

        if (self.index == self.frames.len - 1) {
            if (self.loop) self.reset();
        } else {
            self.timer.reset();
            self.index += 1;
        }
    }

    pub fn reset(self: *@This()) void {
        self.timer.reset();
        self.index = 0;
    }

    pub fn finished(self: *const @This()) bool {
        return self.timer.finished and !self.loop;
    }
};
