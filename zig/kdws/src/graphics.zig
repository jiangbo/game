const std = @import("std");

const cache = @import("cache.zig");
const gpu = @import("gpu.zig");
const math = @import("math.zig");
const animation = @import("animation.zig");

pub const Texture = gpu.Texture;

pub var renderer: gpu.Renderer = undefined;
var matrix: [16]f32 = undefined;
var passEncoder: gpu.RenderPassEncoder = undefined;

pub fn init(width: f32, height: f32) void {
    matrix = .{
        2 / width, 0.0,         0.0, 0.0,
        0.0,       2 / -height, 0.0, 0.0,
        0.0,       0.0,         1,   0.0,
        -1,        1,           0,   1.0,
    };
    renderer = gpu.Renderer.init();
}

pub fn loadTexture(path: [:0]const u8) Texture {
    return cache.Texture.load(path);
}

pub fn beginDraw() void {
    passEncoder = gpu.CommandEncoder.beginRenderPass(
        .{ .r = 1, .b = 1, .a = 1.0 },
        &matrix,
    );

    renderer.renderPass = passEncoder;
}

pub fn drawRectangle(rect: math.Rectangle) void {
    gpu.drawRectangleLine(rect);
}

pub fn draw(tex: Texture, x: f32, y: f32) void {
    drawFlipX(tex, .{ .x = x, .y = y }, false);
}

pub fn drawFlipX(tex: Texture, pos: math.Vector, flipX: bool) void {
    const target: math.Rectangle = .{ .x = pos.x, .y = pos.y };
    const src = math.Rectangle{
        .w = if (flipX) -tex.width() else tex.width(),
    };

    drawOptions(tex, .{ .sourceRect = src, .targetRect = target });
}

pub const DrawOptions = struct {
    sourceRect: ?math.Rectangle = null,
    targetRect: math.Rectangle,
};

pub fn drawOptions(texture: Texture, options: DrawOptions) void {
    renderer.draw(.{
        .uniform = .{ .vp = matrix },
        .texture = texture,
        .sourceRect = options.sourceRect,
        .targetRect = options.targetRect,
    });
}

pub fn endDraw() void {
    passEncoder.submit();
}

pub const FrameAnimation = animation.FrameAnimation;
pub const SliceFrameAnimation = animation.SliceFrameAnimation;
pub const AtlasFrameAnimation = animation.AtlasFrameAnimation;

pub fn playSlice(frameAnimation: *const FrameAnimation, pos: math.Vector) void {
    playSliceFlipX(frameAnimation, pos, false);
}

pub fn playSliceFlipX(frame: *const FrameAnimation, pos: math.Vector, flipX: bool) void {
    const offset: math.Vector = switch (frame.anchor) {
        .bottomCenter => .{
            .x = pos.x - frame.textures[0].width() / 2,
            .y = pos.y - frame.textures[0].height(),
        },
        .centerCenter => .{
            .x = pos.x - frame.textures[0].width() / 2,
            .y = pos.y - frame.textures[0].height() / 2,
        },
        else => unreachable,
    };
    drawFlipX(frame.textures[frame.index], offset, flipX);
}

pub fn playAtlas(frameAnimation: *const AtlasFrameAnimation, pos: math.Vector) void {
    playAtlasFlipX(frameAnimation, pos, false);
}

pub fn playAtlasFlipX(frame: *const AtlasFrameAnimation, pos: math.Vector, flipX: bool) void {
    var src = frame.frames[frame.index];

    const offset: math.Vector = switch (frame.anchor) {
        .bottomCenter => .{ .x = pos.x - src.w / 2, .y = pos.y - src.h },
        .centerCenter => .{ .x = pos.x - src.w / 2, .y = pos.y - src.h / 2 },
        else => unreachable,
    };

    const dst: gpu.Rectangle = .{ .x = offset.x, .y = offset.y, .w = src.w };
    if (flipX) src.w = -src.w;
    drawOptions(frame.texture, .{ .sourceRect = src, .targetRect = dst });
}
