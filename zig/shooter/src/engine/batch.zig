const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");

const Vector2 = math.Vector2;
const Matrix = math.Matrix;
const Texture = gpu.Texture;

pub var pipeline: gpu.RenderPipeline = undefined;
pub var usingTexture: gpu.Texture = undefined;
pub var sampler: gpu.Sampler = undefined;

var bindGroup: gpu.BindGroup = .{};
var gpuBuffer: gpu.Buffer = undefined;
var vertexBuffer: std.ArrayList(QuadVertex) = .empty;

const DrawCommand = struct { scale: Vector2 = .one, texture: Texture };
const CommandUnion = union(enum) { draw: DrawCommand, scissor: math.Rect };
const Command = struct { start: u32 = 0, end: u32, cmd: CommandUnion };
var commands: [16]Command = undefined;
var commandIndex: u32 = 0;
var windowSize: Vector2 = undefined;

pub const QuadVertex = extern struct {
    position: math.Vector3, // 顶点坐标
    radian: f32 = 0, // 旋转弧度
    size: math.Vector2, // 大小
    pivot: math.Vector2 = .zero, // 旋转中心
    texture: math.Vector4, // 纹理坐标
    color: math.Vector4 = .one, // 顶点颜色
};

pub fn init(size: Vector2, buffer: []QuadVertex) void {
    windowSize = size;

    gpuBuffer = gpu.createBuffer(.{
        .size = @sizeOf(QuadVertex) * buffer.len,
        .usage = .{ .stream_update = true },
    });
    vertexBuffer = .initBuffer(buffer);

    const shaderDesc = shader.quadShaderDesc(gpu.queryBackend());
    pipeline = createQuadPipeline(shaderDesc);
    sampler = gpu.nearestSampler;
}

pub const Option = struct {
    size: ?Vector2 = null, // 大小
    anchor: Vector2 = .zero, // 锚点
    pivot: Vector2 = .center, // 旋转中心
    radian: f32 = 0, // 旋转弧度
    color: math.Vector4 = .one, // 颜色
    flipX: bool = false, // 是否水平翻转
};

pub fn beginDraw(color: gpu.Color) void {
    gpu.begin(color);
    commandIndex = 0;
    vertexBuffer.clearRetainingCapacity();
}

pub fn endDraw(pos: Vector2) void {
    defer gpu.end();
    if (vertexBuffer.items.len == 0) return; // 没需要绘制的东西

    commands[commandIndex].end = @intCast(vertexBuffer.items.len);
    gpu.updateBuffer(gpuBuffer, vertexBuffer.items);
    var drawCmd: DrawCommand = undefined;
    for (commands[0 .. commandIndex + 1]) |cmd| {
        switch (cmd.cmd) {
            .draw => |d| drawCmd = d,
            .scissor => |area| gpu.scissor(area),
        }
        drawInstanced(pos, cmd, drawCmd);
    }
}

pub fn drawOption(texture: Texture, pos: Vector2, option: Option) void {
    var textureVector: math.Vector4 = texture.area.toVector4();
    if (option.flipX) {
        std.mem.swap(f32, &textureVector.x, &textureVector.z);
    }

    const size = option.size orelse texture.size();
    var worldPos = pos.sub(size.mul(option.anchor));

    drawVertices(texture, &.{QuadVertex{
        .position = worldPos.toVector3(0),
        .radian = option.radian,
        .size = size,
        // 默认旋转点为中心位置，如果不旋转则传 0
        .pivot = if (option.radian == 0) .zero else option.pivot,
        .texture = textureVector,
        .color = option.color,
    }});
}

pub fn drawVertices(texture: Texture, vertex: []const QuadVertex) void {
    const changed = texture.view.id != usingTexture.view.id;
    if (changed) usingTexture = texture; // 纹理改变，修改使用中的纹理

    if (vertexBuffer.items.len == 0) { // 第一次绘制
        const cmd = CommandUnion{ .draw = .{ .texture = texture } };
        commands[commandIndex] = .{ .end = 0, .cmd = cmd };
    } else if (changed) startNewDrawCommand(); // 纹理改变，开始新的命令

    vertexBuffer.appendSliceAssumeCapacity(vertex);
}

pub fn startNewDrawCommand() void {
    encodeCommand(.{ .draw = .{ .texture = usingTexture } });
}

pub fn encodeCommand(cmd: CommandUnion) void {
    const index: u32 = @intCast(vertexBuffer.items.len);
    commands[commandIndex].end = index;
    commandIndex += 1;
    commands[commandIndex].cmd = cmd;
    commands[commandIndex].start = index;
}

fn drawInstanced(position: Vector2, cmd: Command, drawCmd: DrawCommand) void {
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
    bindGroup.setTexture(drawCmd.texture);
    bindGroup.setVertexBuffer(gpuBuffer);
    bindGroup.setVertexOffset(cmd.start * @sizeOf(QuadVertex));
    bindGroup.setSampler(sampler);

    gpu.setBindGroup(bindGroup);

    // 绘制
    gpu.drawInstanced(cmd.end - cmd.start);
}

pub fn createQuadPipeline(shaderDesc: gpu.ShaderDesc) gpu.RenderPipeline {
    var vertexLayout = gpu.VertexLayoutState{};

    vertexLayout.attrs[0].format = .FLOAT3;
    vertexLayout.attrs[1].format = .FLOAT;
    vertexLayout.attrs[2].format = .FLOAT2;
    vertexLayout.attrs[3].format = .FLOAT2;
    vertexLayout.attrs[4].format = .FLOAT4;
    vertexLayout.attrs[5].format = .FLOAT4;
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
