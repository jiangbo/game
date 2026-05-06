const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const graphics = @import("graphics.zig");
const batch = @import("batch.zig");

const Image = graphics.Image;
const Vector2 = math.Vector2;
const Color = graphics.Color;
pub const String = []const u8;

pub const BitMapFont = struct {
    size: f32,
    lineHeight: f32,
    chars: []const BitMapChar,
};

pub const BitMapChar = struct {
    id: u32,
    area: math.Rect,
    offset: Vector2,
};

var invalidIndex: usize = 0;

var font: BitMapFont = undefined;
var fontImage: graphics.Image = undefined;
var fontScale: f32 = undefined;
var halfAdvance: f32 = undefined; // 英文只需要前进半个距离

pub fn initBitMapFont(image: Image, zon: BitMapFont, size: f32) void {
    font = zon;
    fontImage = image;
    fontScale = size / font.size;
    halfAdvance = font.size / 2;
    invalidIndex = binarySearch('?').?;
    // font.init(fontZon);
    // font.initSDF(.{
    //     .font = fontZon,
    //     .image = image,
    // });
}

fn binarySearch(unicode: u32) ?usize {
    return std.sort.binarySearch(BitMapChar, font.chars, unicode, struct {
        fn compare(a: u32, b: BitMapChar) std.math.Order {
            return std.math.order(a, b.id);
        }
    }.compare);
}

pub fn searchChar(code: u32) *const BitMapChar {
    return &font.chars[binarySearch(code) orelse invalidIndex];
}

pub const Option = struct {
    size: ?f32 = null, // 文字的大小，没有则使用默认值
    color: graphics.Color = .white, // 文字的颜色
    maxWidth: f32 = std.math.floatMax(f32), // 最大宽度，超过换行
    spacing: f32 = 0, // 文字间的间距
};

pub fn drawNumber(number: anytype, pos: Vector2) void {
    drawNumberColor(number, pos, .white);
}

pub fn drawNumberColor(number: anytype, pos: Vector2, color: Color) void {
    var textBuffer: [15]u8 = undefined;
    const string = format(&textBuffer, "{d}", .{number});
    drawColor(string, pos, color);
}

pub fn draw(string: String, pos: math.Vector) void {
    drawOption(string, pos, .{});
}

pub fn drawTextCenter(str: String, pos: Vector2, option: Option) void {
    const width = computeTextWidthOption(str, option);
    drawOption(str, .xy(pos.x - width / 2, pos.y), option);
}

pub fn drawRight(str: String, pos: Vector2, option: Option) void {
    const width = computeTextWidthOption(str, option);
    drawOption(str, .xy(pos.x - width, pos.y), option);
}

pub fn drawFmt(comptime fmt: String, pos: Vector2, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    drawOption(format(&buffer, fmt, args), pos, .{});
}

pub fn drawColor(str: String, pos: Vector2, color: Color) void {
    drawOption(str, pos, .{ .color = color });
}

const Utf8View = std.unicode.Utf8View;
pub fn drawOption(text: String, position: Vector2, option: Option) void {
    const scale = if (option.size) |s| s / font.size else fontScale;
    const height = font.lineHeight * scale;
    var pos = position;

    var iterator = Utf8View.initUnchecked(text).iterator();
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') {
            pos = .xy(position.x, pos.y + height);
            continue;
        }
        if (pos.x > option.maxWidth) {
            pos = .xy(position.x, pos.y + height);
        }
        const char = searchChar(code);
        graphics.textCount += 1;

        const image = fontImage.sub(char.area);
        batch.drawImage(image, pos.add(char.offset.scale(scale)), .{
            .size = char.area.size.scale(scale),
            .color = option.color,
        });

        const advance = if (char.id < 128) halfAdvance else font.size;
        pos = pos.addX(advance * scale + option.spacing);
    }
}

pub fn computeTextWidth(text: String) f32 {
    return computeTextWidthOption(text, .{});
}

pub fn computeTextWidthOption(text: String, option: Option) f32 {
    var width: f32 = 0;
    const scale = if (option.size) |s| s / font.size else fontScale;
    var iterator = Utf8View.initUnchecked(text).iterator();
    while (iterator.nextCodepoint()) |code| {
        const advance = if (code < 128) halfAdvance else font.size;
        width += advance * scale + option.spacing;
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

pub fn nextIndex(str: []const u8, index: usize) usize {
    const next = std.unicode.utf8ByteSequenceLength(str[index]);
    return index + (next catch unreachable);
}
