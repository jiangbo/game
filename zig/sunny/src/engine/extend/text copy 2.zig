const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const graphics = @import("graphics.zig");
const font = @import("font.zig");

const Font = font.Font;
const Glyph = font.Glyph;
const Vector = math.Vector2;

pub const String = []const u8;

var fontImage: graphics.Image = undefined;
var textSize: f32 = 18;
pub var count: u32 = 0;

pub fn init(fontZon: Font, image: graphics.Image, size: f32) void {
    fontImage = image;
    textSize = size;
    font.init(fontZon);
    // font.initSDF(.{
    //     .font = fontZon,
    //     .image = image,
    // });
}

pub fn drawNumber(number: anytype, position: Vector) void {
    drawNumberColor(number, position, .one);
}

pub fn drawNumberColor(number: anytype, pos: Vector, color: Color) void {
    var textBuffer: [15]u8 = undefined;
    const text = format(&textBuffer, "{d}", .{number});
    drawColor(text, pos, color);
}

pub fn draw(text: String, position: math.Vector) void {
    drawOption(text, position, .{});
}

pub fn drawCenter(text: String, pos: Vector, option: Option) void {
    const width = computeTextWidthOption(text, option);
    drawOption(text, .init(pos.x - width / 2, pos.y), option);
}

pub fn drawRight(text: String, pos: Vector, option: Option) void {
    const width = computeTextWidthOption(text, option);
    drawOption(text, .init(pos.x - width, pos.y), option);
}

pub fn drawFmt(comptime fmt: String, pos: Vector, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    draw(format(&buffer, fmt, args), pos);
}

const Color = math.Vector4;
pub fn drawColor(text: String, pos: Vector, color: Color) void {
    drawOption(text, pos, .{ .color = color });
}

pub const Option = struct {
    size: ?f32 = null, // 文字的大小，没有则使用默认值
    color: math.Vector4 = .one, // 文字的颜色
    maxWidth: f32 = std.math.floatMax(f32), // 最大宽度，超过换行
    spacing: f32 = 0, // 文字间的间距
};

const Utf8View = std.unicode.Utf8View;
pub fn drawOption(text: String, position: Vector, option: Option) void {
    const size = option.size orelse textSize;
    const height = font.zon.metrics.lineHeight * size;
    const offsetY = -font.zon.metrics.ascender * size;
    var pos = position.addY(offsetY);

    var iterator = Utf8View.initUnchecked(text).iterator();
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') {
            pos = .init(position.x, pos.y + height);
            continue;
        }
        if (pos.x > option.maxWidth) {
            pos = .init(position.x, pos.y + height);
        }
        const char = font.searchGlyph(code);
        count += 1;

        const target = char.planeBounds.toArea();
        const image = fontImage.map(char.atlasBounds.toArea());
        graphics.draw(image, pos.add(target.min.scale(size)), .{
            .size = target.size.scale(size),
            .color = option.color,
        });
        pos = pos.addX(char.advance * size + option.spacing);
    }
}

pub fn computeTextWidth(text: String) f32 {
    return computeTextWidthOption(text, .{});
}

pub fn computeTextWidthOption(text: String, option: Option) f32 {
    var width: f32 = 0;
    const sz = option.size orelse textSize; // 提供则获取，没有则获取默认值
    var iterator = Utf8View.initUnchecked(text).iterator();
    while (iterator.nextCodepoint()) |code| {
        width += font.searchGlyph(code).advance * sz + option.spacing;
    }
    return width - option.spacing;
}

pub fn computeTextCount(text: String) u32 {
    var iterator = Utf8View.initUnchecked(text).iterator();
    var total: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code != '\n') total += 1;
    }
    return total;
}

pub fn encodeUtf8(buffer: []u8, unicode: []const u21) []u8 {
    var len: usize = 0;
    for (unicode) |code| {
        // 将单个 unicode 编码为 utf8
        len += std.unicode.utf8Encode(code, buffer[len..]) //
            catch std.debug.panic("illegal unicode: {}", .{code});
    }
    return buffer[0..len];
}

pub fn format(buf: []u8, comptime fmt: String, args: anytype) []u8 {
    return std.fmt.bufPrint(buf, fmt, args) catch @panic("text too long");
}

var globalBuffer: [1024]u8 = undefined;
pub fn globalFormat(comptime fmt: String, args: anytype) []u8 {
    return format(&globalBuffer, fmt, args);
}

pub fn globalFormatNumber(args: anytype) []u8 {
    return globalFormat("{d}", .{args});
}
