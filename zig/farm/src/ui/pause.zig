const zhu = @import("zhu");

const storage = @import("../storage.zig");

const panelSize: zhu.Vector2 = .{ .x = 208, .y = 344 };
const Mode = enum { title, play };
pub const Request = enum { close, save, load, title };

pub var cfg: *storage.Config = undefined;
var menu: zhu.widget.Menu = @import("pause.zon");

pub fn open(mode: Mode) void {
    menu.disabled = switch (mode) {
        .title => &.{ 1, 2, 3 },
        .play => &.{},
    };
    menu.position = zhu.window.size.sub(panelSize).scale(0.5);
}

pub fn update() ?Request {
    if (menu.update(.{})) |event| switch (event) {
        0 => return .close,
        1 => return .save, // 选择槽位后保存
        2 => return .load, // 选择槽位后读取
        3 => return .title,
        4 => cfg.speed = @max(0.1, cfg.speed - 0.1),
        5 => cfg.speed += 0.1, // 加速
        6 => cfg.music = zhu.clamp(cfg.music - 0.1, 0, 1),
        7 => cfg.music = zhu.clamp(cfg.music + 0.1, 0, 1),
        8 => cfg.sound = zhu.clamp(cfg.sound - 0.1, 0, 1),
        9 => cfg.sound = zhu.clamp(cfg.sound + 0.1, 0, 1),
        else => unreachable,
    };
    return null;
}

pub fn draw() void {
    // 全屏覆盖
    const overlayRect = zhu.Rect.init(.zero, zhu.window.size);
    zhu.batch.drawRect(overlayRect, .{ .color = .gray(0, 0.35) });

    // 暂停面板背景
    const back = zhu.Rect.init(menu.position, panelSize);
    zhu.batch.drawRect(back, .{ .color = .gray(0, 0.45) });

    menu.draw();

    for (0..3) |index| {
        var buffer: [40]u8 = undefined;
        const string: []const u8 = switch (index) {
            0 => zhu.format(&buffer, "Speed {d:.2}x", .{cfg.speed}),
            1 => zhu.format(&buffer, "Music {d:.0}%", .{
                cfg.music * 100,
            }),
            2 => zhu.format(&buffer, "SFX {d:.0}%", .{
                cfg.sound * 100,
            }),
            else => unreachable,
        };

        const y = 212 + @as(f32, @floatFromInt(index)) * 38;
        const rect = zhu.Rect.init(.xy(24, y), .xy(160, 32));
        const pos = rect.move(menu.position).center();
        zhu.text.draw(string, pos, .{
            .anchor = .center,
        });
    }
}
