const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");
const assets = @import("assets.zig");
const gfx = @import("graphics.zig");
const audio = @import("audio.zig");

pub const Event = sk.app.Event;
pub const KeyCode = sk.app.Keycode;
pub const Char = struct {
    id: u32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    xOffset: f32,
    yOffset: f32,
    xAdvance: f32,
    page: u8,
    chnl: u8,
};

pub const Timer = struct {
    duration: f32,
    elapsed: f32 = 0,

    pub fn init(duration: f32) Timer {
        return Timer{ .duration = duration };
    }

    pub fn update(self: *Timer, delta: f32) void {
        if (self.elapsed < self.duration) self.elapsed += delta;
    }

    pub fn isRunningAfterUpdate(self: *Timer, delta: f32) bool {
        self.update(delta);
        return self.isRunning();
    }

    pub fn isFinishedAfterUpdate(self: *Timer, delta: f32) bool {
        return !self.isRunningAfterUpdate(delta);
    }

    pub fn isRunning(self: *const Timer) bool {
        return self.elapsed < self.duration;
    }

    pub fn stop(self: *Timer) void {
        self.elapsed = self.duration;
    }

    pub fn reset(self: *Timer) void {
        self.elapsed = 0;
    }
};

pub var lastKeyState: std.StaticBitSet(512) = .initEmpty();
pub var keyState: std.StaticBitSet(512) = .initEmpty();

pub fn isKeyDown(keyCode: KeyCode) bool {
    return keyState.isSet(@intCast(@intFromEnum(keyCode)));
}

pub fn isAnyKeyDown(keys: []const KeyCode) bool {
    for (keys) |key| if (isKeyDown(key)) return true;
    return false;
}

pub fn isKeyPress(keyCode: KeyCode) bool {
    const key: usize = @intCast(@intFromEnum(keyCode));
    return !lastKeyState.isSet(key) and keyState.isSet(key);
}

pub fn isAnyKeyPress(keys: []const KeyCode) bool {
    for (keys) |key| if (isKeyPress(key)) return true;
    return false;
}

pub fn isKeyRelease(keyCode: KeyCode) bool {
    const key: usize = @intCast(@intFromEnum(keyCode));
    return lastKeyState.isSet(key) and !keyState.isSet(key);
}

pub fn isAnyKeyRelease(keys: []const KeyCode) bool {
    for (keys) |key| if (isKeyRelease(key)) return true;
    return false;
}

pub fn showCursor(show: bool) void {
    sk.app.showMouse(show);
}

pub const WindowInfo = struct {
    title: [:0]const u8,
    size: math.Vector,
    chars: []const Char = &.{},
};

pub fn call(object: anytype, comptime name: []const u8, args: anytype) void {
    if (@hasDecl(object, name)) @call(.auto, @field(object, name), args);
}

pub var size: math.Vector = .zero;
pub var allocator: std.mem.Allocator = undefined;
var timer: std.time.Timer = undefined;

const root = @import("root");
pub fn run(alloc: std.mem.Allocator, info: WindowInfo) void {
    timer = std.time.Timer.start() catch unreachable;
    size = info.size;
    allocator = alloc;

    if (info.chars.len != 0) {
        const len: u32 = @intCast(info.chars.len);
        fonts.ensureTotalCapacity(alloc, len) catch unreachable;
    }
    for (info.chars) |char| {
        fonts.putAssumeCapacity(char.id, char);
    }

    sk.app.run(.{
        .window_title = info.title,
        .width = @as(i32, @intFromFloat(size.x)),
        .height = @as(i32, @intFromFloat(size.y)),
        .high_dpi = true,
        .init_cb = windowInit,
        .event_cb = windowEvent,
        .frame_cb = windowFrame,
        .cleanup_cb = windowDeinit,
    });
}

export fn windowInit() void {
    assets.init(allocator);

    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });

    sk.debugtext.setup(.{
        .fonts = init: {
            var f: [8]sk.debugtext.FontDesc = @splat(.{});
            f[0] = sk.debugtext.fontKc854();
            break :init f;
        },
        .logger = .{ .func = sk.log.func },
    });

    // gfx.init(size);

    math.setRandomSeed(timer.lap());
    call(root, "init", .{});
}

pub var fonts: std.AutoHashMapUnmanaged(u32, Char) = .empty;
pub var lineHeight: f32 = 0;
pub var fontTexture: gfx.Texture = undefined;
pub var mousePosition: math.Vector = .zero;
var lastButtonState: std.StaticBitSet(3) = .initEmpty();
var buttonState: std.StaticBitSet(3) = .initEmpty();

pub fn isButtonPress(button: sk.app.Mousebutton) bool {
    const code: usize = @intCast(@intFromEnum(button));
    return !lastButtonState.isSet(code) and buttonState.isSet(code);
}

pub fn isButtonRelease(button: sk.app.Mousebutton) bool {
    const code: usize = @intCast(@intFromEnum(button));
    return lastButtonState.isSet(code) and !buttonState.isSet(code);
}

export fn windowEvent(event: ?*const Event) void {
    if (event) |ev| {
        const keyCode: usize = @intCast(@intFromEnum(ev.key_code));
        const buttonCode: usize = @intCast(@intFromEnum(ev.mouse_button));
        switch (ev.type) {
            .KEY_DOWN => keyState.set(keyCode),
            .KEY_UP => keyState.unset(keyCode),
            .MOUSE_MOVE => {
                var pos = math.Vector.init(ev.mouse_x, ev.mouse_y);
                pos = pos.div(.init(sk.app.widthf(), sk.app.heightf()));
                mousePosition = pos.mul(size);
            },
            .MOUSE_DOWN => buttonState.set(buttonCode),
            .MOUSE_UP => buttonState.unset(buttonCode),
            else => {},
        }
        call(root, "event", .{ev});
    }
}

pub fn showFrameRate() void {
    if (frameRateTimer.isRunningAfterUpdate(deltaSeconds)) {
        frameRateCount += 1;
        logicNanoSeconds += timer.read();
    } else {
        frameRateTimer.reset();
        realFrameRate = frameRateCount;
        frameRateCount = 1;
        logicFrameRate = std.time.ns_per_s / logicNanoSeconds * realFrameRate;
        logicNanoSeconds = 0;
    }

    var buffer: [64]u8 = undefined;
    const fmt = std.fmt.bufPrintZ;
    var text = fmt(&buffer, "real frame rate: {d}", .{realFrameRate});
    displayText(2, 2, text catch unreachable);

    text = fmt(&buffer, "logic frame rate: {d}", .{logicFrameRate});
    displayText(2, 4, text catch unreachable);
    endDisplayText();
}

var frameRateTimer: Timer = .init(1);
var frameRateCount: u32 = 0;
var realFrameRate: u32 = 0;
var logicNanoSeconds: u64 = 0;
var logicFrameRate: u64 = 0;
var deltaSeconds: f32 = 0;

export fn windowFrame() void {
    const deltaNano: f32 = @floatFromInt(timer.lap());
    deltaSeconds = deltaNano / std.time.ns_per_s;

    sk.fetch.dowork();
    call(root, "frame", .{deltaSeconds});

    lastKeyState = keyState;
    lastButtonState = buttonState;
}

export fn windowDeinit() void {
    call(root, "deinit", .{});
    sk.debugtext.shutdown();
    fonts.deinit(allocator);
    sk.gfx.shutdown();
    assets.deinit();
}

pub fn displayText(x: f32, y: f32, text: [:0]const u8) void {
    sk.debugtext.canvas(sk.app.widthf() * 0.4, sk.app.heightf() * 0.4);
    sk.debugtext.origin(x, y);
    sk.debugtext.home();

    sk.debugtext.font(0);
    sk.debugtext.color3b(0xff, 0xff, 0xff);
    sk.debugtext.puts(text);
}

pub fn endDisplayText() void {
    sk.debugtext.draw();
}

pub fn exit() void {
    sk.app.requestQuit();
}

pub const File = assets.File;
pub const loadTexture = assets.loadTexture;
pub const playSound = audio.playSound;
pub const playMusic = audio.playMusic;
pub const stopMusic = audio.stopMusic;
pub const random = math.random;
