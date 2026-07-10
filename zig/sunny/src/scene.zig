const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;

const title = @import("title.zig");
const map = @import("map.zig");
const menu = @import("menu.zig");
const player = @import("player.zig");
const object = @import("object.zig");

const Session = extern struct {
    level: u8 = 0,
    health: u8 = 3,
    score: u32 = 0,
    highScore: u32 = 0,
};

const StateEnum = enum { title, play, pause, over };

const savePath = "save/save.dat";
var session: Session = .{};
var state: StateEnum = .title;
var win: bool = false;
var allocator: zhu.Allocator = undefined;

pub fn init(allocator_: zhu.Allocator) void {
    allocator = allocator_;
    zhu.camera.main.position = .zero;
    if (state == .title) return title.init();

    menu.menuIndex = 1;
    map.init(allocator, session.level);

    for (map.objects.items, 0..) |obj, index| {
        if (obj.type != .player) continue;
        player.init(obj.position, obj.size);
        player.health = session.health;
        player.score = session.score;
        _ = map.objects.swapRemove(index);
        break;
    }
    object.init(map.objects);

    zhu.audio.playMusic("audio/hurry_up_and_run.ogg");
}

pub fn start() void {
    state = .play;
    session = .{};
    init(allocator);
}

pub fn load() void {
    state = .play;
    session = loadSession();
    init(allocator);
}

fn loadSession() Session {
    var buffer: [64]u8 = undefined;
    const content = zhu.window.readBuffer(savePath, &buffer) catch {
        return .{};
    };

    var reader = std.Io.Reader.fixed(content);
    return reader.takeStruct(Session, .little) catch unreachable;
}

fn saveSession() !void {
    session.health = player.health;
    session.score = player.score;
    session.highScore = @max(player.score, session.highScore);

    var buffer: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try writer.writeStruct(session, .little);

    try zhu.window.saveAll(savePath, buffer[0..writer.end]);
}

pub fn changeNextLevel() void {
    if (session.level + 1 == map.maps.len) {
        // 最后一关
        win = true;
        state = .over;
        menu.menuIndex = 2;
    } else {
        session.level += 1;
        saveSession() catch unreachable;
        init(allocator);
    }
}

fn backToTitle() void {
    state = .title;
    std.log.info("back to title", .{});
    init(allocator);
}

pub fn deinit(allocator_: zhu.Allocator) void {
    map.deinit(allocator_);
}

pub fn update(delta: f32) void {
    if (zhu.key.held(.LEFT_ALT) and zhu.key.released(.ENTER)) {
        return window.toggleFullScreen();
    }

    switch (state) {
        .title => title.update(delta),
        .play => {
            // 玩家死亡
            if (player.position.y > map.map.grid.size().y + 10) {
                state = .over;
                menu.menuIndex = 2;
            }
            player.update(delta);
            object.update(delta);
            if (zhu.key.released(.ESCAPE)) state = .pause;
        },
        .pause => if (menu.update()) |event| {
            switch (event) {
                0 => state = .play, // 继续游戏
                1 => saveSession() catch unreachable, // 保存存档
                2 => backToTitle(), // 返回标题
                3 => zhu.window.exit(), // 退出游戏
                else => unreachable,
            }
        },
        .over => if (menu.update()) |event| {
            switch (event) {
                0 => backToTitle(), // 返回标题
                1 => start(), // 重新开始
                else => unreachable,
            }
        },
    }
}

pub fn draw() void {
    zhu.batch.beginDraw();
    zhu.batch.useTarget(.black, .{});
    defer zhu.batch.endDraw();

    if (state == .title) return title.draw();

    map.draw();
    object.draw();
    player.draw();

    zhu.camera.push(.window);
    defer zhu.camera.pop();

    if (state == .pause) {
        const size = zhu.window.size;
        const pos: zhu.Vector2 = .xy(size.x * 0.5, size.y * 0.2);
        zhu.text.draw("PAUSE", pos, .{
            .anchor = .center,
            .scale = zhu.text.sizeToScale(32),
        });
        menu.draw();
    } else if (state == .over) drawOver();
}

fn drawOver() void {
    const str = if (win) "YOU WIN! CONGRATS!" else "YOU DIED! TRY AGAIN!";
    const color: zhu.Color = if (win) .green else .red;

    const size = zhu.window.size;
    var pos: zhu.Vector2 = .xy(size.x * 0.5, size.y * 0.3);
    zhu.text.draw(str, pos, .{
        .anchor = .center,
        .scale = zhu.text.sizeToScale(48),
        .color = color,
    });

    var buffer: [128]u8 = undefined;
    var text = zhu.text.format(&buffer, "Score: {}", .{player.score});
    pos = .xy(size.x * 0.5, size.y * 0.5);
    zhu.text.draw(text, pos, .{
        .anchor = .center,
        .scale = zhu.text.sizeToScale(32),
    });

    text = zhu.text.format(&buffer, "High Score: {}", .{session.highScore});
    pos = .xy(size.x * 0.5, size.y * 0.6);
    zhu.text.draw(text, pos, .{
        .anchor = .center,
        .scale = zhu.text.sizeToScale(32),
    });

    menu.draw();
}
