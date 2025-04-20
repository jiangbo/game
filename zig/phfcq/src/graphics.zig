const std = @import("std");

const cache = @import("cache.zig");
const gpu = @import("gpu.zig");
const math = @import("math.zig");
const animation = @import("animation.zig");

pub const Texture = gpu.Texture;

pub const Camera = struct {
    rect: math.Rectangle = .{},

    pub fn lookAt(self: *Camera, pos: math.Vector) void {
        self.rect.x = pos.x - self.rect.w / 2;
        self.rect.y = pos.y - self.rect.h / 2;
    }
};

pub var renderer: gpu.Renderer = undefined;
var matrix: [16]f32 = undefined;
var passEncoder: gpu.RenderPassEncoder = undefined;
pub var camera: Camera = undefined;

pub fn init(size: math.Vector) void {
    matrix = .{
        2 / size.x, 0.0,         0.0, 0.0,
        0.0,        2 / -size.y, 0.0, 0.0,
        0.0,        0.0,         1,   0.0,
        -1,         1,           0,   1.0,
    };
    renderer = gpu.Renderer.init();
}

pub const deinit = gpu.deinit;

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

pub fn draw(tex: Texture, position: math.Vector) void {
    drawFlipX(tex, position, false);
}

pub fn drawFlipX(tex: Texture, pos: math.Vector, flipX: bool) void {
    const target: math.Rectangle = .init(pos, .zero);
    const src = math.Rectangle{ .max = .{
        .x = if (flipX) -tex.width() else tex.width(),
    } };

    drawOptions(tex, .{ .sourceRect = src, .targetRect = target });
}

pub const DrawOptions = struct {
    sourceRect: math.Rectangle = .{},
    targetRect: math.Rectangle = .{},
    angle: f32 = 0,
    pivot: math.Vector = .zero,
    alpha: f32 = 1,
};

pub fn drawOptions(texture: Texture, options: DrawOptions) void {
    matrix[12] = -1 - camera.rect.min.x * matrix[0];
    matrix[13] = 1 - camera.rect.min.y * matrix[5];

    var src, var dst = .{ options.sourceRect, options.targetRect };
    if (src.min.x == src.max.x) src.max.x = src.min.x + texture.width();
    if (src.min.y == src.max.y) src.max.y = src.min.y + texture.height();
    if (dst.min.x == dst.max.x) dst.max.x = dst.min.x + texture.width();
    if (dst.min.y == dst.max.y) dst.max.y = dst.min.y + texture.height();

    renderer.draw(.{
        .uniform = .{ .vp = matrix },
        .texture = texture,
        .sourceRect = src,
        .targetRect = dst,
        .radians = std.math.degreesToRadians(options.angle),
        .pivot = options.pivot,
        .alpha = options.alpha,
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
    const offset = pos.add(frame.offset);
    drawFlipX(frame.textures[frame.index], offset, flipX);
}

pub fn playAtlas(frameAnimation: *const AtlasFrameAnimation, pos: math.Vector) void {
    playAtlasFlipX(frameAnimation, pos, false);
}

pub fn playAtlasFlipX(frame: *const AtlasFrameAnimation, pos: math.Vector, flipX: bool) void {
    var src = frame.frames[frame.index];
    const offset = pos.add(frame.offset);

    const dst: gpu.Rectangle = .{ .x = offset.x, .y = offset.y, .w = src.w };
    if (flipX) src.w = -src.w;
    drawOptions(frame.texture, .{ .sourceRect = src, .targetRect = dst });
}
