const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const assets = @import("assets.zig");
const window = @import("window.zig");

pub const Texture = gpu.Texture;
pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const queryBackend = gpu.queryBackend;

pub const Vector2 = math.Vector2;

pub const ImageId = assets.Id;
pub const createWhiteImage = assets.createWhiteImage;
pub const loadImage = assets.loadImage;

pub const Frame = struct { area: math.Rect, interval: f32 = 0.1 };

pub fn EnumFrameAnimation(comptime T: type) type {
    return std.EnumArray(T, FrameAnimation);
}
pub const FrameAnimation = struct {
    elapsed: f32 = 0,
    index: u8 = 0,
    image: Image,
    frames: []const Frame,
    state: u8 = 0,

    pub fn init(image: Image, frames: []const Frame) FrameAnimation {
        return .{ .image = image, .frames = frames };
    }

    pub fn initFinished(image: Image, frames: []const Frame) FrameAnimation {
        const index: u8 = @intCast(frames.len + 1);
        return .{ .image = image, .frames = frames, .index = index };
    }

    pub fn currentImage(self: *const FrameAnimation) Image {
        return self.image.sub(self.frames[self.index].area);
    }

    pub fn onceUpdate(self: *FrameAnimation, delta: f32) void {
        _ = self.isNextOnceUpdate(delta);
    }

    pub fn isNextOnceUpdate(self: *FrameAnimation, delta: f32) bool {
        if (self.index > self.frames.len) return false; // 已停止

        if (self.index < self.frames.len) {
            self.elapsed += delta;
            const current = self.frames[self.index]; // 当前帧
            if (self.elapsed < current.interval) return false;
            self.elapsed -= current.interval;
        }
        self.index += 1;
        return true;
    }

    pub fn isFinishedOnceUpdate(self: *FrameAnimation, delta: f32) bool {
        self.onceUpdate(delta);
        return self.index >= self.frames.len;
    }

    pub fn loopUpdate(self: *FrameAnimation, delta: f32) void {
        self.elapsed += delta;
        const current = self.frames[self.index]; // 当前帧
        if (self.elapsed < current.interval) return;
        self.elapsed -= current.interval;
        self.index += 1;
        // 结束了从头开始
        if (self.index >= self.frames.len) self.index = 0;
    }

    pub fn getEnumState(self: *const FrameAnimation, T: type) T {
        return @enumFromInt(self.state);
    }

    pub fn stop(self: *FrameAnimation) void {
        self.index = @intCast(self.frames.len + 1);
    }

    pub fn isRunning(self: *const FrameAnimation) bool {
        return self.index < self.frames.len;
    }

    pub fn isFinished(self: *const FrameAnimation) bool {
        return self.index >= self.frames.len;
    }

    pub fn isJustFinished(self: *const FrameAnimation) bool {
        return self.index == self.frames.len;
    }

    pub fn reset(self: *FrameAnimation) void {
        self.index = 0;
        self.elapsed = 0;
    }
};

pub fn framesX(comptime count: u8, size: Vector2, d: f32) [count]Frame {
    var result: [count]Frame = undefined;
    for (&result, 0..) |*frame, i| {
        const index: f32 = @floatFromInt(i);
        frame.area = .init(.xy(index * size.x, 0), size);
        frame.interval = d;
    }
    return result;
}

pub const Image = struct {
    texture: gpu.Texture,
    area: math.Rect,

    pub fn width(self: *const Image) f32 {
        return self.area.size.x;
    }

    pub fn height(self: *const Image) f32 {
        return self.area.size.y;
    }

    pub fn size(self: *const Image) math.Vector2 {
        return self.area.size;
    }

    pub fn sub(self: *const Image, area: math.Rect) Image {
        const moved = area.move(self.area.min);
        return .{ .texture = self.texture, .area = moved };
    }

    pub fn map(self: *const Image, area: math.Rect) Image {
        return .{ .texture = self.texture, .area = area };
    }
};

pub const Atlas = struct {
    imagePath: [:0]const u8,
    size: math.Vector2,
    images: []const struct { id: ImageId, area: math.Rect },
};

pub fn imageId(comptime path: []const u8) ImageId {
    return comptime assets.id(path);
}

pub fn getImage(comptime path: []const u8) Image {
    return assets.getImage(imageId(path));
}

pub var textCount: u32 = 0;
pub fn beginDraw(clearColor: ClearColor) void {
    gpu.begin(clearColor);
    textCount = 0;
}

pub const ClearColor = gpu.Color;
pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const black = Color.rgb(0, 0, 0); // 黑色
    pub const white = Color.rgb(255, 255, 255); // 白色
    pub const midGray = Color.rgb(128, 128, 128); // 中灰色

    pub const red = Color.rgb(255, 0, 0); // 红色
    pub const green = Color.rgb(0, 255, 0); // 绿色
    pub const blue = Color.rgb(0, 0, 255); // 蓝色

    pub const yellow = Color.rgb(255, 255, 0); // 黄色
    pub const cyan = Color.rgb(0, 255, 255); // 青色
    pub const magenta = Color.rgb(255, 0, 255); // 品红色

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn gray(v: u8, a: u8) Color {
        return .{ .r = v, .g = v, .b = v, .a = a };
    }
};

// pub fn init(size: Vector2, buffer: []Vertex) void {
//     batch.init(size, buffer);
// }

// pub fn scissor(area: math.Rect) void {
//     const min = area.min.mul(window.ratio);
//     const size = area.size.mul(window.ratio);
//     batch.encodeCommand(.{ .scissor = .{ .min = min, .size = size } });
// }
// pub fn resetScissor() void {
//     batch.encodeCommand(.{ .scissor = .fromMax(.zero, window.clientSize) });
// }

// pub fn encodeScaleCommand(scale: Vector2) void {
//     batch.setScale(scale);
//     batch.startNewDrawCommand();
//     要解决开始新的绘制命令后，从哪里获取纹理
// }
