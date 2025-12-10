const std = @import("std");

pub const window = @import("window.zig");
pub const assets = @import("assets.zig");
pub const audio = @import("audio.zig");
pub const gfx = @import("graphics.zig");
pub const camera = @import("camera.zig");
pub const math = @import("math.zig");
pub const input = @import("input.zig");
pub const ecs = @import("ecs.zig");
pub const text = @import("text.zig");

pub fn format(buffer: []u8, comptime fmt: []const u8, args: anytype) []u8 {
    return std.fmt.bufPrint(buffer, fmt, args) catch unreachable;
}

pub fn formatZ(buffer: []u8, comptime fmt: []const u8, args: anytype) [:0]u8 {
    return std.fmt.bufPrintZ(buffer, fmt, args) catch unreachable;
}

const Utf8View = std.unicode.Utf8View;
pub fn utf8Len(str: []const u8) usize {
    const utf8 = Utf8View.init(str) catch unreachable;
    var count: usize = 0;
    var it = utf8.iterator();
    while (it.nextCodepoint()) count += 1;
    return count;
}

pub fn utf8NextIndex(str: []const u8, index: usize) usize {
    const next = std.unicode.utf8ByteSequenceLength(str[index]);
    return index + (next catch unreachable);
}

pub const random = math.random;
pub const randomF32 = math.randomF32;
pub const randomInt = math.randomInt;
pub const randomIntMost = math.randomIntMost;
pub const randomEnum = math.randomEnum;
pub const randomBool = math.randomBool;
