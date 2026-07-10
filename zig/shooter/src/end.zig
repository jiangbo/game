const std = @import("std");
const zhu = @import("zhu");

const player = @import("player.zig");
const scene = @import("scene.zig");

var allocator: std.mem.Allocator = undefined;
var nameUnicode: [20]u21 = undefined;
var nameIndex: u8 = 0;
var nameBuffer: [nameUnicode.len * 3]u8 = undefined;
var name: []u8 = &.{};

var blink: bool = true; // 输入光标闪烁
var blinkTimer: zhu.Timer = .init(0.7); // 输入光标闪烁
const Score = struct { name: []const u8, score: u32 = 0 };
var scoreBoard: [8]Score = undefined; // 最多显示 8 个
var scoreCount: u8 = 0; // 没有任何得分记录

pub fn init(allocator_: std.mem.Allocator) void {
    allocator = allocator_;
    loadScore() catch |err| std.log.info("load score failed: {}", .{err});
}

pub fn restart() void {
    nameIndex = 0;
}

pub fn handleEvent(event: *const zhu.window.Event) void {
    if (!scene.isTyping or event.type != .CHAR) return;
    if (nameIndex >= nameUnicode.len - 1) return;

    // 临时保存输入的用户名。
    nameUnicode[nameIndex] = @intCast(event.char_code);
    nameIndex += 1;
    name = zhu.text.encodeUtf8(&nameBuffer, nameUnicode[0..nameIndex]);
}

pub fn update(delta: f32) void {
    if (blinkTimer.updateFinished(delta)) {
        blink = !blink;
        blinkTimer.restart();
    }

    if (scene.isTyping) return updateTyping();

    if (zhu.key.pressed(.J)) scene.restart();
}

fn updateTyping() void {
    if (nameIndex == 0) return;

    if (zhu.key.pressed(.BACKSPACE)) {
        nameIndex -= 1;
        name = zhu.text.encodeUtf8(&nameBuffer, nameUnicode[0..nameIndex]);
    }

    if (zhu.key.pressed(.ENTER)) {
        scene.isTyping = false;
        updateScore(player.score);
    }
}

fn updateScore(score: u32) void {
    if (scoreCount == scoreBoard.len and
        player.score <= scoreBoard[scoreCount - 1].score) return;

    defer saveScore() catch @panic("save score failed");

    const scoreName = allocator.dupe(u8, name) catch @panic("score oom");
    const toInsert: Score = .{ .name = scoreName, .score = score };

    for (scoreBoard[0..scoreCount], 0..) |boardScore, i| {
        if (boardScore.score < score) {
            if (scoreCount == scoreBoard.len) {
                allocator.free(scoreBoard[scoreCount - 1].name);
            } else scoreCount += 1;
            const dest = scoreBoard[i + 1 .. scoreBoard.len];
            @memmove(dest, scoreBoard[i .. scoreBoard.len - 1]);
            scoreBoard[i] = toInsert;
            return;
        }
    }

    scoreBoard[scoreCount] = toInsert;
    scoreCount += 1;
}

pub fn draw() void {
    if (scene.isTyping) return drawTyping();

    zhu.window.drawCenter("得分榜", 0.1, .{
        .scale = zhu.text.sizeToScale(72),
        .spacing = 5,
    });

    var y = 0.25 * zhu.window.size.y;
    for (scoreBoard[0..scoreCount], 0..) |score, i| {
        var nameTextBuffer: [128]u8 = undefined;
        const nameText = zhu.format(&nameTextBuffer, "{}. {s}", .{
            i + 1,
            score.name,
        });
        zhu.text.draw(nameText, .xy(100, y), .{});

        var scoreTextBuffer: [32]u8 = undefined;
        const scoreText = zhu.format(&scoreTextBuffer, "{}", .{
            score.score,
        });
        const size = zhu.text.measure(scoreText, .{});
        const x = zhu.window.size.x - 100 - size.x;
        zhu.text.draw(scoreText, .xy(x, y), .{});
        y += 50;
    }

    if (blink) {
        zhu.window.drawCenter("按J键重新开始游戏", 0.8, .{
            .spacing = 5,
        });
    }
}

fn drawTyping() void {
    var buffer: [255]u8 = undefined;
    const score = zhu.format(&buffer, "你的得分是：{}", .{player.score});
    zhu.window.drawCenter(score, 0.1, .{ .spacing = 2 });

    zhu.window.drawCenter("GAME OVER", 0.35, .{
        .scale = zhu.text.sizeToScale(72),
        .spacing = 5,
    });

    const typing = "请输入你的名字，按回车键确认：";
    zhu.window.drawCenter(typing, 0.6, .{ .spacing = 2 });

    if (nameIndex == 0) {
        if (blink) zhu.window.drawCenter("_", 0.8, .{ .spacing = 2 });
    } else {
        const width = zhu.text.measure(name, .{ .spacing = 2 }).x;
        const x = (zhu.window.size.x - width) / 2;
        const pos: zhu.Vector2 = .xy(x, zhu.window.size.y * 0.8);
        zhu.text.draw(name, pos, .{ .spacing = 2 });
        if (blink) zhu.text.draw("_", pos.addX(width + 4), .{});
    }
}

const magic = [2]u8{ 0xB0, 0x0B };
fn saveScore() !void {
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try writer.writeAll(&magic);
    try writer.writeAll(&.{ 0x00, 0x00 });

    for (scoreBoard[0..scoreCount]) |value| {
        const len: u8 = @intCast(value.name.len);
        try writer.writeByte(len);
        try writer.writeAll(value.name);
        try writer.writeAll(std.mem.asBytes(&value.score));
    }

    try zhu.window.saveAll("save/score.dat", buffer[0..writer.end]);
}

fn loadScore() !void {
    const slice = try zhu.window.readAll(allocator, "save/score.dat");
    defer allocator.free(slice);

    var index: usize = 0;
    if (slice.len < 4) return error.EndOfStream;

    if (!std.mem.eql(u8, slice[index..][0..magic.len], &magic)) return;
    index += magic.len;
    index += 2;

    while (index < slice.len) {
        const len = slice[index];
        index += 1;

        if (index + len + 4 > slice.len) return error.EndOfStream;
        const n = allocator.dupe(u8, slice[index..][0..len])
            catch @panic("score oom");
        index += len;

        const score = std.mem.readInt(u32, slice[index..][0..4], .little);
        index += 4;

        scoreBoard[scoreCount] = .{ .name = n, .score = score };
        scoreCount += 1;
    }
}

pub fn deinit() void {
    for (scoreBoard[0..scoreCount]) |score| {
        allocator.free(score.name);
    }
}
