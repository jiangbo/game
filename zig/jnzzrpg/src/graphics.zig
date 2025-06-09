const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const assets = @import("assets.zig");
const window = @import("window.zig");

pub const camera = @import("camera.zig");

pub const Texture = gpu.Texture;
pub const Color = gpu.Color;
pub const Vector = math.Vector;
pub const FourDirection = math.FourDirection;
pub const Rectangle = math.Rectangle;
pub const loadTexture = assets.loadTexture;

pub const FrameAnimation = FixedFrameAnimation(4, 0.1);

pub fn FixedFrameAnimation(maxSize: u8, time: f32) type {
    return struct {
        timer: window.Timer = .init(time),
        index: usize = 0,
        loop: bool = true,
        texture: Texture,
        frames: [maxSize]math.Rectangle,
        count: u8 = maxSize,
        offset: math.Vector = .zero,

        const Animation = @This();

        pub fn init(texture: Texture) Animation {
            return initWithCount(texture, maxSize);
        }

        pub fn initWithCount(texture: Texture, count: u8) Animation {
            var frames: [maxSize]math.Rectangle = undefined;

            const floatCount: f32 = @floatFromInt(count);
            const width = @divExact(texture.width(), floatCount);
            const size: math.Vector = .{ .x = width, .y = texture.height() };

            for (0..count) |index| {
                const x = @as(f32, @floatFromInt(index)) * width;
                frames[index] = .init(.init(x, texture.area.min.y), size);
            }

            return .{ .texture = texture, .frames = frames, .count = count };
        }

        pub fn addFrame(self: *Animation, rect: math.Rectangle) void {
            self.frames[self.count] = rect;
            self.count += 1;
        }

        pub fn currentTexture(self: *const Animation) Texture {
            return self.texture.mapTexture(self.frames[self.index]);
        }

        pub fn update(self: *Animation, delta: f32) void {
            if (self.timer.isRunningAfterUpdate(delta)) return;

            if (self.index == self.count - 1) {
                if (self.loop) self.reset();
            } else {
                self.timer.reset();
                self.index += 1;
            }
        }

        pub fn anchor(self: *Animation, direction: math.EightDirection) void {
            const tex = self.texture;
            self.offset = switch (direction) {
                .down => .{ .x = -tex.width() / 2, .y = -tex.height() },
                else => unreachable,
            };
        }

        pub fn anchorCenter(self: *Animation) void {
            self.offset.x = -self.texture.width() / 2;
            self.offset.y = -self.texture.height() / 2;
        }

        pub fn reset(self: *Animation) void {
            self.timer.reset();
            self.index = 0;
        }

        pub fn stop(self: *Animation) void {
            self.timer.elapsed = self.timer.duration;
            self.index = self.count - 1;
            self.loop = false;
        }

        pub fn finished(self: *const Animation) bool {
            return !self.timer.isRunning() and !self.loop;
        }
    };
}
