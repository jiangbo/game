const std = @import("std");

pub const window = @import("window.zig");
pub const assets = @import("assets.zig");
pub const audio = @import("audio.zig");
pub const graphics = @import("graphics.zig");
pub const batch = @import("batch.zig");
pub const math = @import("math.zig");
pub const input = @import("input.zig");
pub const ecs = @import("ecs.zig");
pub const text = @import("text.zig");
pub const extend = struct {
    pub const tiled = @import("extend/tiled.zig");
};

pub const Timer = math.Timer;
pub const Atlas = graphics.Atlas;
pub const Vector2 = math.Vector2;
pub const Rect = math.Rect;
pub const Color = graphics.Color;

pub fn imageId(comptime path: []const u8) graphics.ImageId {
    return comptime assets.id(path);
}

pub fn getImage(comptime path: []const u8) graphics.Image {
    return assets.getImage(imageId(path));
}

pub fn nextEnum(E: type, value: anytype) E {
    const len = @typeInfo(E).@"enum".fields.len;
    if (@typeInfo(@TypeOf(value)) == .int) {
        return @enumFromInt((value + 1) % len);
    }
    return @enumFromInt((@intFromEnum(value) + 1) % len);
}

pub const random = math.random;
pub const randomF32 = math.randomF32;
pub const randomInt = math.randomInt;
pub const randomIntMost = math.randomIntMost;
pub const randomEnum = math.randomEnum;
pub const randomBool = math.randomBool;
