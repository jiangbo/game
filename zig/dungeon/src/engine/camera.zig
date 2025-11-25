const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const window = @import("window.zig");
const font = @import("font.zig");

const Texture = gpu.Texture;
const Vector = math.Vector;
const Vector2 = math.Vector2;
const Rect = math.Rect;
const Color = math.Vector4;
pub const Vertex = gpu.QuadVertex;

pub var mode: enum { world, local } = .world;
pub var position: math.Vector = .zero;
pub var scale: math.Vector = .one;
pub var whiteTexture: gpu.Texture = undefined;

var startDraw: bool = false;

var bindGroup: gpu.BindGroup = .{};
var pipeline: gpu.RenderPipeline = undefined;

var buffer: gpu.Buffer = undefined;
var needDrawCount: usize = 0;
var totalDrawCount: usize = 0;
var usingTexture: gpu.Texture = .{ .view = .{} };

pub fn init(vertexCount: usize) void {
    buffer = gpu.createBuffer(.{
        .size = @sizeOf(Vertex) * vertexCount,
        .usage = .{ .stream_update = true },
    });

    const shaderDesc = shader.quadShaderDesc(gpu.queryBackend());
    pipeline = gpu.createQuadPipeline(shaderDesc);
}

pub fn initWithWhiteTexture(vertexCount: usize) void {
    init(vertexCount);
    const data: [64]u8 = [1]u8{0xFF} ** 64;
    whiteTexture = gpu.createTexture(.init(4, 4), &data);
}

pub fn toWorld(windowPosition: Vector) Vector {
    return windowPosition.add(position);
}

pub fn toWindow(worldPosition: Vector) Vector {
    return worldPosition.sub(position);
}

pub fn beginDraw(color: gpu.Color) void {
    gpu.begin(color);
    startDraw = true;
    totalDrawCount = 0;
    font.beginDraw();
}

pub fn debugDraw(area: math.Rect) void {
    drawRect(area, .{ .x = 1, .z = 1, .w = 0.4 });
}

pub fn draw(texture: gpu.Texture, pos: math.Vector) void {
    drawOption(texture, pos, .{});
}

pub fn drawFlipX(texture: Texture, pos: Vector, flipX: bool) void {
    drawOption(texture, pos, .{ .flipX = flipX });
}

pub fn drawRectLine(start: Vector, end: Vector, color: Color) void {
    if (start.x == end.x) {
        drawRect(.init(start, .init(end.y - start.y, 1)), color);
    } else if (start.y == end.y) {
        drawRect(.init(start, .init(1, end.x - start.x)), color);
    }
}

pub fn drawRectBorder(area: Rect, width: f32, color: Color) void {
    drawRect(.init(area.min, .init(area.size.x, width)), color); // 上
    var start = area.min.addY(area.size.y - width);
    drawRect(.init(start, .init(area.size.x, width)), color); // 下
    const size: Vector2 = .init(width, area.size.y - 2 * width);
    drawRect(.init(area.min.addY(width), size), color); // 左
    start = area.min.addXY(area.size.x - width, width);
    drawRect(.init(start, size), color); // 右
}

pub fn drawRect(area: math.Rect, color: Color) void {
    drawOption(whiteTexture, area.min, .{
        .size = area.size,
        .color = color,
    });
}

pub const Option = struct {
    size: ?Vector2 = null, // 大小
    pivot: Vector2 = .zero, // 旋转中心
    color: Color = .one, // 颜色
    flipX: bool = false, // 是否水平翻转
};
pub fn drawOption(texture: Texture, pos: Vector, option: Option) void {
    var textureVector: math.Vector4 = texture.area.toVector4();
    if (option.flipX) {
        std.mem.swap(f32, &textureVector.x, &textureVector.z);
    }

    const size = option.size orelse texture.size();
    var temp = pos.sub(size.mul(option.pivot));
    if (mode == .local) temp = temp.add(position);

    drawVertices(texture, &.{Vertex{
        .position = temp.toVector3(0),
        .size = size,
        .texture = textureVector,
        .color = option.color,
    }});
}

pub fn drawVertices(texture: Texture, vertex: []const Vertex) void {
    if (!startDraw) @panic("need begin draw");
    gpu.appendBuffer(buffer, vertex);

    defer {
        needDrawCount += vertex.len;
        totalDrawCount += vertex.len;
        usingTexture = texture;
    }

    if (totalDrawCount == 0) return; // 第一次绘制
    if (texture.view.id != usingTexture.view.id) flushTexture();
}

pub fn flushTexture() void {
    if (needDrawCount == 0) return;

    drawInstanced(usingTexture, .{
        .vertexBuffer = buffer,
        .vertexOffset = totalDrawCount - needDrawCount,
        .count = needDrawCount,
    });
    needDrawCount = 0;
}

pub fn flushTextureAndText() void {
    flushTexture();
    font.flush();
}

pub fn endDraw() void {
    flushTextureAndText();
    startDraw = false;
    gpu.end();
}

pub fn scissor(area: math.Rect) void {
    flushTextureAndText();
    gpu.scissor(math.Rect{
        .min = area.min.mul(window.ratio),
        .size = area.size.mul(window.ratio),
    });
}
pub fn resetScissor() void {
    flushTextureAndText();
    gpu.scissor(.fromMax(.zero, window.clientSize));
}

const VertexOptions = struct {
    vertexBuffer: gpu.Buffer,
    vertexOffset: usize = 0,
    count: usize,
};
fn drawInstanced(texture: Texture, options: VertexOptions) void {

    // 绑定流水线
    gpu.setPipeline(pipeline);

    // 处理 uniform 变量
    const x, const y = .{ window.logicSize.x, window.logicSize.y };
    const orth = math.Matrix.orthographic(x, y, 0, 1);
    const pos = position.scale(-1).toVector3(0);
    const translate = math.Matrix.translateVec(pos);
    const scaleMatrix = math.Matrix.scaleVec(scale.toVector3(1));
    const view = math.Matrix.mul(scaleMatrix, translate);

    const size = gpu.queryTextureSize(texture);
    gpu.setUniform(shader.UB_vs_params, .{
        .viewMatrix = math.Matrix.mul(orth, view).mat,
        .textureVec = [4]f32{ 1 / size.x, 1 / size.y, 1, 1 },
    });

    // 绑定组
    bindGroup.setTexture(texture);
    bindGroup.setVertexBuffer(options.vertexBuffer);
    bindGroup.setVertexOffset(options.vertexOffset * @sizeOf(Vertex));
    bindGroup.setSampler(gpu.nearestSampler);

    gpu.setBindGroup(bindGroup);

    // 绘制
    gpu.drawInstanced(options.count);
}

pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const queryBackend = gpu.queryBackend;
pub const drawNumber = font.drawNumber;
pub const drawColorNumber = font.drawColorNumber;
pub const drawText = font.drawText;
pub const drawColorText = font.drawColorText;
pub const drawTextOptions = font.drawTextOptions;
pub const flushText = font.flush;

pub fn imageDrawCount() usize {
    return totalDrawCount;
}

pub fn textDrawCount() usize {
    return font.totalDrawCount;
}
