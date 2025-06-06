const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const http = @import("http.zig");

const Stage = enum { waiting, ready, racing, finished };
const Player = @import("Player.zig");
const BASE_URL = "http://127.0.0.1:4444/api";
const SPEED = 100;

var cameraScene: gfx.Camera = .{};
var cameraUI: gfx.Camera = .{};
var stage: Stage = .waiting;

var text: std.ArrayList(u8) = undefined;
var lines: std.BoundedArray([]const u8, 100) = undefined;
const paths = blk: {
    var temp = [_]math.Vector{
        .{ .x = 842, .y = 842 },
        .{ .x = 1322, .y = 842 },
        .{ .x = 1322, .y = 442 },
        .{ .x = 2762, .y = 442 },
        .{ .x = 2762, .y = 842 },
        .{ .x = 3162, .y = 842 },
        .{ .x = 3162, .y = 1722 },
        .{ .x = 2122, .y = 1722 },
        .{ .x = 2122, .y = 1562 },
        .{ .x = 842, .y = 1562 },
    };
    for (0..temp.len - 1) |index| {
        const len = temp[index + 1].sub(temp[index]).length();
        temp[index + 1].z = len;
    }
    break :blk temp;
};
var totalLength: f32 = 0;
var totalChar: f32 = 0;
var currentLine: u8 = 0;
var currentChar: u8 = 0;
var finishedChar: f32 = 0;

var player1: Player = undefined;
var player2: Player = undefined;

var ui1: gfx.Texture = undefined;
var ui2: gfx.Texture = undefined;
var ui3: gfx.Texture = undefined;
var uiFight: gfx.Texture = undefined;

var textbox: gfx.Texture = undefined;

var endTimer: window.Timer = .init(4);

pub fn init(allocator: std.mem.Allocator) void {
    for (paths) |path| totalLength += path.z;

    cameraScene.setSize(window.size);
    cameraUI.setSize(window.size);

    player1 = Player.init(1);
    player2 = Player.init(2);
    player1.anchorCenter();
    player2.anchorCenter();

    text = http.sendAlloc(allocator, BASE_URL ++ "/text");
    lines = std.BoundedArray([]const u8, 100).init(0) catch unreachable;

    var iter = std.mem.tokenizeScalar(u8, text.items, '\n');
    while (iter.next()) |line| {
        lines.appendAssumeCapacity(line);
        totalChar += @as(f32, @floatFromInt(line.len));
    }

    playerIndex = http.sendValue(i32, BASE_URL ++ "/login", null);
    player1.position = paths[0];
    player2.position = paths[0];
    cameraScene.lookAt(paths[0]);

    ui1 = gfx.loadTexture("assets/ui_1.png");
    ui2 = gfx.loadTexture("assets/ui_2.png");
    ui3 = gfx.loadTexture("assets/ui_3.png");
    uiFight = gfx.loadTexture("assets/ui_fight.png");
    textbox = gfx.loadTexture("assets/ui_textbox.png");

    if (playerIndex == 1) {
        player1Progress.store(0, .release);
    } else {
        player2Progress.store(0, .release);
    }

    const thread = std.Thread.spawn(.{}, syncProgress, .{}) catch unreachable;
    thread.detach();
}

pub fn deinit() void {
    _ = http.sendValue(i32, BASE_URL ++ "/logout", playerIndex);
    text.deinit();
    audio.stopMusic();
}

pub fn event(ev: *const window.Event) void {
    if (stage != .racing) return;

    if (ev.type == .CHAR and ev.char_code > 0 and ev.char_code < 127) {
        const line = lines.get(currentLine);
        if (@as(u8, @intCast(ev.char_code)) == line[currentChar]) {
            const rand = math.randomU8(1, 5);
            switch (rand) {
                1 => audio.playSound("assets/click_1.ogg"),
                2 => audio.playSound("assets/click_2.ogg"),
                3 => audio.playSound("assets/click_3.ogg"),
                4 => audio.playSound("assets/click_4.ogg"),
                else => unreachable,
            }

            currentChar += 1;
            finishedChar += 1;
            if (currentChar == line.len) {
                currentLine += 1;
                currentChar = 0;
            }

            if (currentLine == lines.len) {
                if (playerIndex == 1) {
                    player1Progress.store(1, .release);
                } else {
                    player2Progress.store(1, .release);
                }
            }
        }
    }
}

var playerIndex: i32 = 0;
var player1Progress: std.atomic.Value(f32) = .init(-1);
var player2Progress: std.atomic.Value(f32) = .init(-1);
var count: i8 = 4;
var timer: window.Timer = .init(1);

pub fn update(delta: f32) void {
    if (stage == .finished) {
        if (endTimer.isRunningAfterUpdate(delta)) return;

        window.exit();
        return;
    }

    if (player1Progress.load(.acquire) == 1) {
        stage = .finished;
        audio.stopMusic();
        audio.playSound("assets/1p_win.ogg");
        if (playerIndex == 1)
            std.log.info("1 win", .{})
        else
            std.log.info("1 lose", .{});
    } else if (player2Progress.load(.acquire) == 1) {
        stage = .finished;
        audio.stopMusic();
        audio.playSound("assets/2p_win.ogg");
        if (playerIndex == 2)
            std.log.info("2 win", .{})
        else
            std.log.info("2 lose", .{});
    }

    player1.currentAnimation().update(delta);
    player2.currentAnimation().update(delta);

    if (stage == .waiting) {
        if (player1Progress.load(.acquire) >= 0 //
        and player2Progress.load(.acquire) >= 0) {
            stage = .ready;
        }
    } else if (stage == .ready) {
        if (timer.isFinishedAfterUpdate(delta)) {
            timer.reset();
            count -= 1;
            switch (count) {
                3 => audio.playSound("assets/ui_3.ogg"),
                2 => audio.playSound("assets/ui_2.ogg"),
                1 => audio.playSound("assets/ui_1.ogg"),
                0 => audio.playSound("assets/ui_fight.ogg"),
                -1 => {
                    stage = .racing;
                    audio.playMusic("assets/bgm.ogg");
                },
                else => unreachable,
            }
        }
    } else {
        updateScene(delta);
    }
}

fn updateScene(delta: f32) void {
    const self = if (playerIndex == 1) &player1 else &player2;
    if (self.keydown) |key| {
        const position: math.Vector = switch (key) {
            .up => .{ .y = -SPEED * delta },
            .down => .{ .y = SPEED * delta },
            .left => .{ .x = -SPEED * delta },
            .right => .{ .x = SPEED * delta },
        };
        self.current = key;
        self.position = self.position.add(position);
    }

    cameraScene.lookAt(self.position);

    if (playerIndex == 1) {
        player1Progress.store(finishedChar / totalChar, .release);
    } else {
        player2Progress.store(finishedChar / totalChar, .release);
    }

    updatePlayer(&player1, player1Progress.load(.acquire), delta);
    updatePlayer(&player2, player2Progress.load(.acquire), delta);

    player1.currentAnimation().update(delta);
    player2.currentAnimation().update(delta);
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.camera = cameraScene;
    const background = gfx.loadTexture("assets/background.png");
    gfx.draw(background, 0, 0);

    if (stage == .waiting) {
        if (playerIndex == 1) {
            gfx.playSlice(player1.currentAnimation(), player1.position);
        } else {
            gfx.playSlice(player2.currentAnimation(), player2.position);
        }
        return;
    } else if (stage == .ready) {
        gfx.playSlice(player1.currentAnimation(), player1.position);
        gfx.playSlice(player2.currentAnimation(), player2.position);

        gfx.camera = cameraUI;
        switch (count) {
            3 => gfx.drawV(ui3, window.size.sub(ui3.size()).scale(0.5)),
            2 => gfx.drawV(ui2, window.size.sub(ui2.size()).scale(0.5)),
            1 => gfx.drawV(ui1, window.size.sub(ui1.size()).scale(0.5)),
            0 => gfx.drawV(uiFight, window.size.sub(uiFight.size()).scale(0.5)),
            else => {},
        }
        return;
    }

    gfx.playSlice(player1.currentAnimation(), player1.position);
    gfx.playSlice(player2.currentAnimation(), player2.position);

    gfx.camera = cameraUI;
    gfx.draw(textbox, 0, 720 - textbox.height());

    if (currentLine >= lines.len) return;
    var buffer: [100]u8 = undefined;
    const line = lines.get(currentLine);

    @memcpy(buffer[0..currentChar], line[0..currentChar]);
    buffer[currentChar] = 0;

    moveTo(11.5, 39.5);
    displayText(buffer[0..currentChar :0], 0, 149, 125);

    @memcpy(buffer[currentChar..line.len], line[currentChar..]);
    buffer[line.len] = 0;
    displayText(buffer[currentChar..line.len :0], 0, 0, 0);

    endDisplayText();
}

fn updatePlayer(player: *Player, progress: f32, delta: f32) void {
    const target = getProgressPosition(progress);
    if (player.position.approx(target)) {
        player.velocity = .zero;
    } else {
        const direction = target.sub(player.position).normalize();
        player.velocity = direction.scale(SPEED);

        player.current = if (direction.x > math.epsilon) .right //
            else if (direction.x < -math.epsilon) .left //
            else if (direction.y > math.epsilon) .down //
            else if (direction.y < -math.epsilon) .up //
            else unreachable;
    }

    const distance = player.velocity.scale(delta);
    if (target.sub(player.position).length() < distance.length()) {
        player.position = target;
    } else {
        player.position = player.position.add(distance);
    }
}

fn getProgressPosition(progress: f32) math.Vector {
    if (progress == 0) return paths[0];
    if (progress >= 1) return paths[paths.len - 1];

    var remaining = totalLength * progress;

    for (paths[1..], 1..) |path, index| {
        if (remaining < path.z) {
            const delta = path.sub(paths[index - 1]).scale(remaining / path.z);
            return paths[index - 1].add(delta);
        }
        remaining -= path.z;
    }
    unreachable;
}

fn syncProgress() void {
    while (stage != .finished) {
        std.time.sleep(100 * std.time.ns_per_ms);

        if (playerIndex == 1) {
            var progress = player1Progress.load(.acquire);
            progress = http.sendValue(f32, BASE_URL ++ "/update1", progress);
            player2Progress.store(progress, .release);
        } else {
            var progress = player2Progress.load(.acquire);
            progress = http.sendValue(f32, BASE_URL ++ "/update2", progress);
            player1Progress.store(progress, .release);
        }
    }
}

const sk = @import("sokol");
fn moveTo(x: f32, y: f32) void {
    sk.debugtext.canvas(sk.app.widthf() * 0.5, sk.app.heightf() * 0.5);
    sk.debugtext.origin(x, y);
    sk.debugtext.home();
}

fn displayText(str: [:0]const u8, r: u8, g: u8, b: u8) void {
    sk.debugtext.font(0);
    sk.debugtext.color3b(r, g, b);
    sk.debugtext.puts(str);
}

fn endDisplayText() void {
    sk.debugtext.draw();
}
