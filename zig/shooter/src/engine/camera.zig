const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const window = @import("window.zig");
const text = @import("text.zig");
const batch = @import("batch.zig");

const Texture = gpu.Texture;
const Vector = math.Vector;
const Vector2 = math.Vector2;
const Rect = math.Rect;
const Color = math.Vector4;
pub const Vertex = batch.QuadVertex;

pub var mode: enum { world, local } = .world;
pub var position: math.Vector = .zero;
pub var whiteTexture: gpu.Texture = undefined;

var startDraw: bool = false;

pub fn init(buffer: []Vertex) void {
    batch.init(window.logicSize, buffer);
}

pub fn initWithWhiteTexture(buffer: []Vertex) void {
    init(buffer);
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
    batch.beginDraw(color);
    startDraw = true;
    text.count = 0;
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

pub const Option = batch.Option;
pub fn drawOption(texture: Texture, pos: Vector, option: Option) void {
    if (!startDraw) @panic("need begin draw");

    var worldPos = pos;
    if (mode == .local) worldPos = pos.add(position);
    batch.drawOption(texture, worldPos, option);
}

pub fn endDraw() void {
    startDraw = false;
    batch.endDraw(position);
}

pub fn scissor(area: math.Rect) void {
    const min = area.min.mul(window.ratio);
    const size = area.size.mul(window.ratio);
    batch.encodeCommand(.{ .scissor = .{ .min = min, .size = size } });
}
pub fn resetScissor() void {
    batch.encodeCommand(.{ .scissor = .fromMax(.zero, window.clientSize) });
}

pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const queryBackend = gpu.queryBackend;
pub const drawNumber = text.drawNumber;
pub const drawText = text.draw;
pub const drawTextColor = text.drawColor;
pub const drawTextOptions = text.drawOption;
pub const computeTextWidth = text.computeTextWidth;
pub const imageDrawCount = batch.imageDrawCount;

pub fn textDrawCount() usize {
    return text.count;
}
