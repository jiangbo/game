const std = @import("std");
const cache = @import("cache.zig");
const gpu = @import("gpu.zig");
const window = @import("window.zig");

pub const Texture = gpu.Texture;

pub const Camera = struct {
    const zm = @import("zmath");

    proj: zm.Mat,

    pub fn init(width: f32, height: f32) Camera {
        const proj = zm.orthographicOffCenterLh(0, width, 0, height, 0, 1);
        return .{ .proj = proj };
    }

    pub fn vp(self: Camera) zm.Mat {
        return self.proj;
    }
};

pub var camera: Camera = undefined;
pub var renderer: gpu.Renderer = undefined;
var passEncoder: gpu.RenderPassEncoder = undefined;

pub fn init(width: f32, height: f32) void {
    camera = Camera.init(width, height);
    renderer = gpu.Renderer.init();
}

pub fn loadTexture(path: [:0]const u8) ?Texture {
    return cache.TextureCache.load(path);
}

pub fn loadTextures(textures: []Texture, comptime pathFmt: []const u8, from: u8) void {
    std.log.info("loading texture slice : {s}", .{pathFmt});

    var buffer: [128]u8 = undefined;
    for (from..from + textures.len) |index| {
        const path = std.fmt.bufPrintZ(&buffer, pathFmt, .{index});

        const texture = loadTexture(path catch unreachable);
        textures[index - from] = texture.?;
    }
}

pub fn beginDraw() void {
    passEncoder = gpu.CommandEncoder.beginRenderPass(.{ .r = 1, .b = 1, .a = 1.0 });
    renderer.renderPass = passEncoder;
}

pub fn draw(x: f32, y: f32, tex: Texture) void {
    drawFlipX(x, y, tex, false);
}

pub fn drawFlipX(x: f32, y: f32, tex: Texture, flipX: bool) void {
    const target: gpu.Rectangle = .{
        .x = x - window.shakeCamera.shakingX,
        .y = y - window.shakeCamera.shakingY,
    };

    const src = gpu.Rectangle{
        .width = if (flipX) -tex.width else tex.width,
    };

    drawOptions(tex, .{ .sourceRect = src, .targetRect = target });
}

pub const DrawOptions = struct {
    sourceRect: ?gpu.Rectangle = null,
    targetRect: gpu.Rectangle,
};
pub const Rectangle = gpu.Rectangle;

pub fn drawOptions(texture: Texture, options: DrawOptions) void {
    renderer.draw(.{
        .uniform = .{ .vp = camera.vp() },
        .texture = texture,
        .sourceRect = options.sourceRect,
        .targetRect = options.targetRect,
    });
}

pub fn endDraw() void {
    passEncoder.submit();
}

pub fn TextureArray(max: u8) type {
    return struct {
        textures: [max]Texture,

        pub fn init(comptime pathFmt: []const u8) @This() {
            var self = @This(){ .textures = undefined };
            cache.TextureSliceCache.loadToSlice(&self.textures, pathFmt, 1);
            return self;
        }

        pub fn asSlice(self: @This()) []const Texture {
            return self.textures[0..];
        }
    };
}

pub const FrameAnimation = SliceFrameAnimation;

pub const SliceFrameAnimation = struct {
    timer: window.Timer,
    index: usize = 0,
    loop: bool = true,

    textures: []const Texture,

    pub fn init(textures: []const Texture) SliceFrameAnimation {
        return .{ .textures = textures, .timer = .init(100) };
    }

    pub fn load(comptime pathFmt: []const u8, max: u8) SliceFrameAnimation {
        const textures = cache.TextureSliceCache.load(pathFmt, 1, max);
        return .init(textures.?);
    }

    pub fn update(self: *@This(), delta: f32) void {
        if (self.timer.isRunningAfterUpdate(delta)) return;

        if (self.index == self.textures.len - 1) {
            if (self.loop) {
                self.index = 0;
                self.timer.reset();
            }
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

    pub fn play(self: *const @This(), x: f32, y: f32) void {
        self.playFlipX(x, y, false);
    }

    pub fn playFlipX(self: *const @This(), x: f32, y: f32, flipX: bool) void {
        drawFlipX(x, y, self.textures[self.index], flipX);
    }
};
