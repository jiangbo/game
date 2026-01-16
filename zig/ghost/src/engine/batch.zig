const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const graphics = @import("graphics.zig");

const Image = graphics.Image;
const Vector2 = math.Vector2;
const Matrix = math.Matrix;
const Texture = gpu.Texture;

pub var pipeline: gpu.RenderPipeline = undefined;
var gpuBuffer: gpu.Buffer = undefined;
var vertexBuffer: std.ArrayList(Vertex) = .empty;

pub var whiteImage: graphics.ImageId = undefined;

const DrawCommand = struct {
    position: Vector2 = .zero, // 位置
    scale: Vector2 = .one, // 缩放
    texture: Texture = .{}, // 纹理
};
const CommandUnion = union(enum) { draw: DrawCommand, scissor: math.Rect };
const Command = struct { start: u32 = 0, end: u32, cmd: CommandUnion };
var commands: [16]Command = undefined;
var commandIndex: u32 = 0;
var windowSize: Vector2 = undefined;

pub const Vertex = extern struct {
    position: math.Vector2, // 顶点坐标
    radian: f32 = 0, // 旋转弧度
    colorScale: f32 = 1, // 颜色缩放
    size: math.Vector2, // 大小
    pivot: math.Vector2 = .zero, // 旋转中心
    texture: math.Vector4, // 纹理坐标
    color: graphics.Color = .white, // 顶点颜色
};

pub fn init(size: Vector2, buffer: []Vertex) void {
    windowSize = size;

    gpuBuffer = gpu.createBuffer(.{
        .size = @sizeOf(Vertex) * buffer.len,
        .usage = .{ .stream_update = true },
    });
    vertexBuffer = .initBuffer(buffer);

    const shaderDesc = shader.quadShaderDesc(gpu.queryBackend());
    pipeline = createQuadPipeline(shaderDesc);
}

pub fn initWithWhiteTexture(size: Vector2, buffer: []Vertex) void {
    init(size, buffer);
    whiteImage = graphics.createWhiteImage("engine/white");
}

pub const Option = struct {
    size: ?Vector2 = null, // 大小
    scale: Vector2 = .one, // 缩放
    anchor: Vector2 = .zero, // 锚点
    pivot: Vector2 = .center, // 旋转中心
    radian: f32 = 0, // 旋转弧度
    color: graphics.Color = .white, // 颜色
    colorScale: f32 = 1, // 颜色缩放
    flipX: bool = false, // 水平翻转
};

pub fn beginDraw(color: graphics.ClearColor) void {
    graphics.beginDraw(color);
    commandIndex = 0;
    commands[commandIndex].cmd.draw = .{};
    vertexBuffer.clearRetainingCapacity();
}

pub fn endDraw(position: Vector2) void {
    defer gpu.end();
    if (vertexBuffer.items.len == 0) return; // 没需要绘制的东西

    commands[commandIndex].end = @intCast(vertexBuffer.items.len);
    gpu.updateBuffer(gpuBuffer, vertexBuffer.items);
    for (commands[0 .. commandIndex + 1]) |cmd| {
        switch (cmd.cmd) {
            .draw => |drawCmd| doDraw(position, cmd, drawCmd),
            .scissor => |area| gpu.scissor(area),
        }
    }
}

pub fn drawImage(image: Image, position: Vector2, option: Option) void {
    const size = (option.size orelse image.area.size);
    const scaledSize = size.mul(option.scale);

    var imageVector: math.Vector4 = image.area.toVector4();
    if (option.flipX) {
        imageVector.x += imageVector.z;
        imageVector.z = -imageVector.z;
    }

    drawVertices(image.texture, &.{Vertex{
        .position = position.sub(scaledSize.mul(option.anchor)),
        .radian = option.radian,
        .size = scaledSize,
        // 默认旋转点为中心位置，如果不旋转则传 0
        .pivot = if (option.radian == 0) .zero else option.pivot,
        .texture = imageVector,
        .color = option.color,
        .colorScale = option.colorScale,
    }});
}

pub fn drawVertices(texture: Texture, vertex: []const Vertex) void {
    const drawCommand = &commands[commandIndex].cmd.draw;
    if (drawCommand.texture.id == 0) {
        drawCommand.texture = texture; // 还没有绘制任何纹理
    } else if (texture.id != drawCommand.texture.id) {
        startNewDrawCommand(); // 纹理改变，开始新的命令
        commands[commandIndex].cmd.draw.texture = texture;
    }

    vertexBuffer.appendSliceAssumeCapacity(vertex);
}

pub fn startNewDrawCommand() void {
    encodeCommand(.{ .draw = .{} });
}

pub fn setScale(scale: Vector2) void {
    commands[commandIndex].cmd.draw.scale = scale;
}

pub fn encodeCommand(cmd: CommandUnion) void {
    const index: u32 = @intCast(vertexBuffer.items.len);
    commands[commandIndex].end = index;
    commandIndex += 1;
    commands[commandIndex].cmd = cmd;
    commands[commandIndex].start = index;
}

fn doDraw(position: Vector2, cmd: Command, drawCmd: DrawCommand) void {
    // 绑定流水线
    gpu.setPipeline(pipeline);

    // 处理 uniform 变量
    const x, const y = .{ windowSize.x, windowSize.y };
    const orth = math.Matrix.orthographic(x, y, 0, 1);
    const pos = position.scale(-1).toVector3(0);
    const translate = math.Matrix.translateVec(pos);
    const scaleMatrix = math.Matrix.scaleVec(drawCmd.scale.toVector3(1));
    const view = math.Matrix.mul(scaleMatrix, translate);

    const size = gpu.queryTextureSize(drawCmd.texture);
    gpu.setUniform(shader.UB_vs_params, .{
        .viewMatrix = math.Matrix.mul(orth, view).mat,
        .textureVec = [4]f32{ 1 / size.x, 1 / size.y, 1, 1 },
    });

    // 绑定组
    var bindGroup: gpu.BindGroup = .{};
    bindGroup.setTexture(drawCmd.texture);
    bindGroup.setVertexBuffer(gpuBuffer);
    bindGroup.setVertexOffset(cmd.start * @sizeOf(Vertex));
    bindGroup.setSampler(gpu.nearestSampler);
    gpu.setBindGroup(bindGroup);

    // 绘制
    gpu.drawInstanced(cmd.end - cmd.start);
}

pub fn createQuadPipeline(shaderDesc: gpu.ShaderDesc) gpu.RenderPipeline {
    var vertexLayout = gpu.VertexLayoutState{};

    vertexLayout.attrs[0].format = .FLOAT2;
    vertexLayout.attrs[1].format = .FLOAT;
    vertexLayout.attrs[2].format = .FLOAT;
    vertexLayout.attrs[3].format = .FLOAT2;
    vertexLayout.attrs[4].format = .FLOAT2;
    vertexLayout.attrs[5].format = .FLOAT4;
    vertexLayout.attrs[6].format = .UBYTE4N;
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
    return commandIndex + 1;
}
