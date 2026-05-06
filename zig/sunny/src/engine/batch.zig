const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const graphics = @import("graphics.zig");
const assets = @import("assets.zig");

const Image = graphics.Image;
const ImageId = graphics.ImageId;
const Color = graphics.Color;
const Vector2 = math.Vector2;
const Matrix = math.Matrix;

const CommandEnum = enum { draw, scissor };
pub const Command = struct {
    start: u32 = 0, // 起始顶点索引
    end: u32 = 0, // 结束顶点索引
    texture: gpu.Texture = .{}, // 纹理
    position: Vector2 = .zero, // 位置
    scale: Vector2 = .one, // 缩放
    commandEnum: CommandEnum = .draw, // 命令类型
};

pub const Vertex = extern struct {
    position: math.Vector2, // 顶点坐标
    radian: f32 = 0, // 旋转弧度
    padding: u32 = 1,
    size: math.Vector2, // 大小
    pivot: math.Vector2 = .zero, // 旋转中心
    texturePosition: math.Vector4, // 纹理坐标
    color: graphics.Color = .white, // 顶点颜色
};

pub var pipeline: gpu.RenderPipeline = undefined;
pub var vertexBuffer: std.ArrayList(Vertex) = .empty;
pub var whiteImage: graphics.Image = undefined;
pub var camera: Camera = undefined;

var commandBuffer: std.ArrayList(Command) = .empty;
var gpuBuffer: gpu.Buffer = undefined;

pub fn init(vertexes: []Vertex, commands: []Command) void {
    gpuBuffer = gpu.createBuffer(.{
        .size = @sizeOf(Vertex) * vertexes.len,
        .usage = .{ .stream_update = true },
    });
    vertexBuffer = .initBuffer(vertexes);
    commandBuffer = .initBuffer(commands);

    const shaderDesc = shader.quadShaderDesc(gpu.queryBackend());
    pipeline = createQuadPipeline(shaderDesc);

    camera = Camera.init();
}

pub fn initWithWhiteTexture(size: Vector2, buffer: []Vertex) void {
    init(size, buffer);
    whiteImage = assets.createWhiteImage("engine/white");
}

pub const Option = struct {
    size: ?Vector2 = null, // 大小
    scale: Vector2 = .one, // 缩放
    anchor: Vector2 = .zero, // 锚点
    pivot: Vector2 = .center, // 旋转中心
    radian: f32 = 0, // 旋转弧度
    color: graphics.Color = .white, // 颜色
    flipX: bool = false, // 水平翻转
};

pub fn beginDraw(color: graphics.Color) void {
    graphics.beginDraw(color);
    vertexBuffer.clearRetainingCapacity();
    commandBuffer.clearRetainingCapacity();
    commandBuffer.appendAssumeCapacity(.{});
}

pub fn endDraw() void {
    defer gpu.end();
    if (vertexBuffer.items.len == 0) return; // 没需要绘制的东西

    currentCommand().end = @intCast(vertexBuffer.items.len);
    gpu.updateBuffer(gpuBuffer, vertexBuffer.items);
    for (commandBuffer.items) |cmd| {
        switch (cmd.commandEnum) {
            .draw => doDraw(cmd),
            .scissor => gpu.scissor(.init(cmd.position, cmd.scale)),
        }
    }
}

pub fn currentCommand() *Command {
    return &commandBuffer.items[commandBuffer.items.len - 1];
}

pub fn debugDraw(area: math.Rect) void {
    drawRect(area, .{ .color = .rgba(1, 0, 1, 0.4) });
}

pub fn draw(image: ImageId, pos: math.Vector2) void {
    drawImageId(image, pos, .{});
}

pub const LineOption = struct { color: Color = .white, width: f32 = 1 };

/// 绘制轴对齐的线
pub fn drawAxisLine(start: Vector2, end: Vector2, option: LineOption) void {
    const rectOption = RectOption{ .color = option.color };
    const halfWidth = -@floor(option.width / 2);
    if (start.x == end.x) {
        const size = Vector2.xy(option.width, end.y - start.y);
        drawRect(.init(start.addX(halfWidth), size), rectOption);
    } else if (start.y == end.y) {
        const size = Vector2.xy(end.x - start.x, option.width);
        drawRect(.init(start.addY(halfWidth), size), rectOption);
    }
}

/// 绘制任意线
pub fn drawLine(start: Vector2, end: Vector2, option: LineOption) void {
    const vector = end.sub(start);
    const y = start.y - option.width / 2;

    drawImage(graphics.whiteImage, .init(start.x, y), .{
        .size = .init(vector.length(), option.width),
        .color = option.color,
        .radian = vector.atan2(),
        .pivot = .init(0, 0.5),
    });
}

pub fn drawRectBorder(area: math.Rect, width: f32, c: Color) void {
    const color = RectOption{ .color = c };
    drawRect(.init(area.min, .xy(area.size.x, width)), color); // 上
    var start = area.min.addY(area.size.y - width);
    drawRect(.init(start, .xy(area.size.x, width)), color); // 下
    const size: Vector2 = .xy(width, area.size.y - 2 * width);
    drawRect(.init(area.min.addY(width), size), color); // 左
    start = area.min.addXY(area.size.x - width, width);
    drawRect(.init(start, size), color); // 右
}

pub const RectOption = struct { color: Color = .white, radian: f32 = 0 };
pub fn drawRect(area: math.Rect, option: RectOption) void {
    const white = whiteImage.sub(.init(.xy(0, 4), .xy(4, 4)));
    drawImage(white, area.min, .{
        .size = area.size,
        .color = option.color,
        .radian = option.radian,
    });
}

pub const TriangleOption = struct {
    color: Color = .white,
    flip: bool = false,
};
pub fn drawTriangle(area: math.Rect, option: TriangleOption) void {
    drawImage(whiteImage, area.min, .{
        .size = area.size,
        .color = option.color,
        .flipX = option.flip,
    });
}

pub fn drawImageId(id: ImageId, pos: Vector2, option: Option) void {
    drawImage(assets.getImage(id), pos, option);
}

pub fn drawImage(image: Image, pos: Vector2, option: Option) void {
    var worldPos = pos;
    if (camera.modeEnum == .window) {
        worldPos = camera.position.add(pos);
    }

    const size = (option.size orelse image.area.size);
    const scaledSize = size.mul(option.scale);

    var imageVector = image.area.toTexturePosition();
    if (option.flipX) {
        imageVector.x += imageVector.z;
        imageVector.z = -imageVector.z;
    }

    var command = currentCommand();
    if (command.texture.id == 0) {
        command.texture = image.texture; // 还没有绘制任何纹理
    } else if (image.texture.id != command.texture.id) {
        startNewDrawCommand(); // 纹理改变，开始新的命令
        currentCommand().texture = image.texture;
    }

    vertexBuffer.appendSliceAssumeCapacity(&.{Vertex{
        .position = worldPos.sub(scaledSize.mul(option.anchor)),
        .radian = option.radian,
        .size = scaledSize,
        .pivot = option.pivot,
        .texturePosition = imageVector,
        .color = option.color,
    }});
}

pub fn startNewDrawCommand() void {
    const index: u32 = @intCast(vertexBuffer.items.len);
    currentCommand().end = index;
    commandBuffer.appendAssumeCapacity(.{ .start = index });
}

fn doDraw(cmd: Command) void {
    // 绑定流水线
    gpu.setPipeline(pipeline);

    // 处理 uniform 变量
    const x, const y = .{ camera.size.x, camera.size.y };
    const orth = math.Matrix.orthographic(x, y, 0, 1);
    const pos = camera.position.scale(-1).toVector3(0);
    const translate = math.Matrix.translateVec(pos);
    const scaleMatrix = math.Matrix.scaleVec(cmd.scale.toVector3(1));
    const view = math.Matrix.mul(scaleMatrix, translate);

    const size = gpu.queryTextureSize(cmd.texture);
    gpu.setUniform(shader.UB_vs_params, .{
        .viewMatrix = math.Matrix.mul(orth, view).mat,
        .textureVec = [4]f32{ 1 / size.x, 1 / size.y, 1, 1 },
    });

    // 绑定组
    var bindGroup: gpu.BindGroup = .{};
    bindGroup.setTexture(cmd.texture);
    bindGroup.setVertexBuffer(gpuBuffer);
    bindGroup.setVertexOffset(cmd.start * @sizeOf(Vertex));
    bindGroup.setSampler(gpu.nearestSampler);
    gpu.setBindGroup(bindGroup);

    // 绘制
    gpu.drawInstanced(cmd.end - cmd.start);
}

fn createQuadPipeline(shaderDesc: gpu.ShaderDesc) gpu.RenderPipeline {
    var vertexLayout = gpu.VertexLayoutState{};

    vertexLayout.attrs[0].format = .FLOAT2;
    vertexLayout.attrs[1].format = .FLOAT;
    vertexLayout.attrs[2].format = .FLOAT;
    vertexLayout.attrs[3].format = .FLOAT2;
    vertexLayout.attrs[4].format = .FLOAT2;
    vertexLayout.attrs[5].format = .FLOAT4;
    vertexLayout.attrs[6].format = .FLOAT4;
    vertexLayout.buffers[0].step_func = .PER_INSTANCE;

    return gpu.createPipeline(.{
        .shader = gpu.createShader(shaderDesc),
        .layout = vertexLayout,
        .primitive_type = .TRIANGLE_STRIP,
        .colors = init: {
            var c: [8]gpu.ColorTargetState = @splat(.{});
            c[0] = .{ .blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
            } };
            break :init c;
        },
    });
}

pub fn imageDrawCount() usize {
    return commandBuffer.items.len;
}

pub const Camera = struct {
    const window = @import("window.zig");

    modeEnum: enum { world, window } = .world,
    position: Vector2 = .zero,
    size: Vector2 = undefined,
    bound: Vector2 = undefined,

    pub fn init() Camera {
        return .{ .size = window.size, .bound = window.size };
    }

    pub fn toWorld(self: Camera, windowPosition: Vector2) Vector2 {
        return windowPosition.add(self.position);
    }

    pub fn toWindow(self: Camera, worldPosition: Vector2) Vector2 {
        return worldPosition.sub(self.position);
    }

    pub fn control(self: *Camera, distance: f32) void {
        if (window.isKeyDown(.UP)) self.position.y -= distance;
        if (window.isKeyDown(.DOWN)) self.position.y += distance;
        if (window.isKeyDown(.LEFT)) self.position.x -= distance;
        if (window.isKeyDown(.RIGHT)) self.position.x += distance;
    }

    pub fn clampBound(self: *Camera) void {
        const max = self.bound.sub(self.size).max(.zero);
        self.position.clamp(.zero, max);
    }

    pub fn directFollow(self: *Camera, pos: Vector2) void {
        self.position = pos.sub(self.size.scale(0.5));
        self.clampBound();
    }

    pub fn smoothFollow(self: *Camera, pos: Vector2, smooth: f32) void {
        const target = pos.sub(self.size.scale(0.5));
        const distance = target.sub(self.position);

        const clampedSmooth = std.math.clamp(smooth, 0, 1);
        if (@abs(distance.x) < 1) self.position.x = target.x else {
            var moved = distance.x * clampedSmooth;
            if (@abs(moved) < 1) moved = math.ceilAway(moved);
            self.position.x += moved;
        }

        if (@abs(distance.y) < 1) self.position.y = target.y else {
            var moved = distance.y * clampedSmooth;
            if (@abs(moved) < 1) moved = math.ceilAway(moved);
            self.position.y += moved;
        }
        self.clampBound();
    }
};
