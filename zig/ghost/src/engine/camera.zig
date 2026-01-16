const std = @import("std");

const math = @import("math.zig");
const text = @import("text.zig");
const assets = @import("assets.zig");
const graphics = @import("graphics.zig");
const batch = @import("batch.zig");

const Color = graphics.Color;
const Vector2 = math.Vector2;
const ImageId = graphics.ImageId;
const Image = graphics.Image;
const String = text.String;

pub var mode: enum { world, local } = .world;
pub var position: Vector2 = .zero;

var startDraw: bool = false;

pub fn toWorld(windowPosition: Vector2) Vector2 {
    return windowPosition.add(position);
}

pub fn toWindow(worldPosition: Vector2) Vector2 {
    return worldPosition.sub(position);
}

pub fn beginDraw(color: graphics.ClearColor) void {
    batch.beginDraw(color);
    startDraw = true;
}

pub fn debugDraw(area: math.Rect) void {
    drawRect(area, .{ .color = .{ .x = 1, .z = 1, .w = 0.4 } });
}

pub fn draw(image: ImageId, pos: math.Vector2) void {
    drawOption(image, pos, .{});
}

pub fn drawFlipX(image: ImageId, pos: Vector2, flipX: bool) void {
    drawOption(image, pos, .{ .flipX = flipX });
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

    drawOption(graphics.whiteImage, .init(start.x, y), .{
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
    drawOption(batch.whiteImage, area.min, .{
        .size = area.size,
        .color = option.color,
        .radian = option.radian,
    });
}

pub const Option = batch.Option;
pub fn drawOption(image: ImageId, pos: Vector2, option: Option) void {
    var worldPos = pos;
    if (mode == .local) worldPos = pos.add(position);
    batch.drawImage(assets.getImage(image), worldPos, option);
}

pub fn drawImage(image: Image, pos: Vector2, option: Option) void {
    if (!startDraw) @panic("need begin draw");

    var worldPos = pos;
    if (mode == .local) worldPos = pos.add(position);
    batch.drawImage(image, worldPos, option);
}

pub fn endDraw() void {
    startDraw = false;
    batch.endDraw(position);
}

pub const imageDrawCount = batch.imageDrawCount;
