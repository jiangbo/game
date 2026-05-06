const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const assets = @import("assets.zig");
const window = @import("window.zig");

pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const queryBackend = gpu.queryBackend;

pub const Vector2 = math.Vector2;

pub const ImageId = assets.Id;

pub const Frame = struct {
    offset: Vector2, // 图集中的偏移位置
    duration: f32 = 0.1, // 持续时间，单位秒
    extend: u32 = 0, // 自由扩展
};

pub fn EnumAnimation(comptime T: type) type {
    return std.EnumArray(T, Animation);
}
pub const Animation = struct {
    pub const Clip = []const Frame;
    pub const Step = enum { none, next, loop, end };

    elapsed: f32 = 0,
    index: u16 = 0,
    image: Image,
    clip: Clip,
    loop: bool = true,
    extend: u32 = 0,

    sourceIndex: u8 = 0,
    sourceLength: u8 = 0,
    source: [*]const Clip = undefined,

    pub fn init(image: Image, clip: Clip) Animation {
        return .{ .image = image, .clip = clip };
    }

    pub fn initFinished(image: Image, clip: Clip) Animation {
        const idx: u8 = @intCast(clip.len);
        return .{ .image = image, .clip = clip, .index = idx };
    }

    pub fn initSource(image: Image, source: []const Clip) Animation {
        var self: Animation = .init(image, source[0]);
        self.source = source.ptr;
        self.sourceLength = @intCast(source.len);
        return self;
    }

    pub fn subImage(self: *const Animation, size: Vector2) Image {
        const index = @min(self.clip.len - 1, self.index);
        const offset = self.clip[index].offset;
        return self.image.sub(.init(offset, size));
    }

    pub fn play(self: *Animation, index: u8, loop: bool) void {
        self.clip = self.source[index];
        self.sourceIndex = index;
        self.loop = loop;
        self.reset();
    }

    pub fn update(self: *Animation, delta: f32) Step {
        if (self.index == self.clip.len) return .none; // 已经结束
        self.elapsed += delta;
        const current = self.clip[self.index];
        if (self.elapsed < current.duration) return .none; // 还未到下一帧

        self.elapsed -= current.duration;
        self.index += 1;
        if (self.index < self.clip.len) return .next; // 下一帧
        if (!self.loop) return .end; // 动画结束
        self.index = 0; // 循环播放
        return .loop;
    }

    pub fn getEnumFrame(self: *const Animation, T: type) T {
        return @enumFromInt(self.clip[self.index].extend);
    }

    pub fn getEnumExtend(self: *const Animation, T: type) T {
        return @enumFromInt(self.extend);
    }

    pub fn stop(self: *Animation) void {
        self.index = @intCast(self.clip.len);
    }

    pub fn isRunning(self: *const Animation) bool {
        return self.index < self.clip.len;
    }

    pub fn isFinished(self: *const Animation) bool {
        return self.index == self.clip.len;
    }

    pub fn reset(self: *Animation) void {
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

pub fn loopFramesX(comptime count: u8, size: Vector2, d: f32) //
[count + count - 2]Frame {
    var result: [count + count - 2]Frame = undefined;
    for (&result, 0..) |*frame, i| {
        var index: f32 = @floatFromInt(i);
        if (i >= count) index = @floatFromInt(count + count - 2 - i);
        frame.area = .init(.xy(index * size.x, 0), size);
        frame.interval = d;
    }
    return result;
}

pub const Image = struct {
    texture: gpu.Texture,
    offset: math.Vector2 = .zero,
    size: math.Vector2,

    pub fn sub(self: *const Image, rect: math.Rect) Image {
        return Image{
            .texture = self.texture,
            .offset = self.offset.add(rect.min),
            .size = rect.size,
        };
    }

    pub fn toTexturePosition(self: Image) math.Vector4 {
        return .initSize(self.offset, self.size);
    }
};

pub const Atlas = struct {
    imagePath: [:0]const u8,
    size: math.Vector2,
    images: []const struct { id: ImageId, rect: math.Rect },
};

pub var textCount: u32 = 0;
pub fn beginDraw(clearColor: Color) void {
    gpu.begin(@bitCast(clearColor), window.viewRect);
    textCount = 0;
}

pub const Color = extern struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub const black = Color.rgb(0, 0, 0); // 黑色
    pub const white = Color.rgb(1, 1, 1); // 白色
    pub const midGray = Color.rgb(0.5, 0.5, 0.5); // 中灰色

    pub const red = Color.rgb(1, 0, 0); // 红色
    pub const green = Color.rgb(0, 1, 0); // 绿色
    pub const blue = Color.rgb(0, 0, 1); // 蓝色

    pub const yellow = Color.rgb(1, 1, 0); // 黄色
    pub const cyan = Color.rgb(0, 1, 1); // 青色
    pub const magenta = Color.rgb(1, 0, 1); // 品红色
    pub fn rgb(r: f32, g: f32, b: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = 1 };
    }

    pub fn rgba(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn gray(v: f32, a: f32) Color {
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
