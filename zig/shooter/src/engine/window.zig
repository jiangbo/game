const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");
const assets = @import("assets.zig");
const audio = @import("audio.zig");
const input = @import("input.zig");
const font = @import("font.zig");
const text = @import("text.zig");
const gpu = @import("gpu.zig");

pub const Event = sk.app.Event;

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

    pub fn progress(self: *const Timer) f32 {
        return self.elapsed / self.duration;
    }

    pub fn restart(self: *Timer) void {
        self.elapsed = self.elapsed - self.duration;
    }

    pub fn stop(self: *Timer) void {
        self.elapsed = self.duration;
    }
};

const CountingAllocator = struct {
    child: std.mem.Allocator,
    used: usize,
    count: usize,

    pub fn init(child: std.mem.Allocator) CountingAllocator {
        return .{ .child = child, .used = 0, .count = 0 };
    }

    pub fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = allocs,
                .resize = resize,
                .remap = remap,
                .free = frees,
            },
        };
    }

    const A = std.mem.Alignment;
    fn allocs(c: *anyopaque, len: usize, a: A, r: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(c));
        const p = self.child.rawAlloc(len, a, r) orelse return null;
        self.count += 1;
        self.used += len;
        return p;
    }

    fn resize(c: *anyopaque, b: []u8, a: A, len: usize, r: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(c));
        const stable = self.child.rawResize(b, a, len, r);
        if (stable) {
            self.count += 1;
            self.used +%= len -% b.len;
        }
        return stable;
    }

    fn remap(c: *anyopaque, m: []u8, a: A, len: usize, r: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(c));
        const n = self.child.rawRemap(m, a, len, r) orelse return null;
        self.count += 1;
        self.used +%= len -% m.len;
        return n;
    }

    fn frees(c: *anyopaque, buf: []u8, a: A, r: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(c));
        self.used -= buf.len;
        return self.child.rawFree(buf, a, r);
    }
};

pub fn showCursor(show: bool) void {
    sk.app.showMouse(show);
}

pub fn toggleFullScreen() void {
    sk.app.toggleFullscreen();
}

pub const WindowInfo = struct {
    title: [:0]const u8,
    logicSize: math.Vector,
    scale: f32 = 1,
};

pub fn call(object: anytype, comptime name: []const u8, args: anytype) void {
    if (@hasDecl(object, name)) @call(.auto, @field(object, name), args);
}

pub var logicSize: math.Vector = .zero;
pub var clientSize: math.Vector = .zero;
pub var ratio: math.Vector = .init(1, 1);
pub var displayArea: math.Rect = undefined;
pub var allocator: std.mem.Allocator = undefined;
pub var countingAllocator: CountingAllocator = undefined;
var timer: std.time.Timer = undefined;

const root = @import("root");
pub fn run(allocs: std.mem.Allocator, info: WindowInfo) void {
    timer = std.time.Timer.start() catch unreachable;
    logicSize = info.logicSize;
    displayArea = .init(.zero, logicSize);
    countingAllocator = CountingAllocator.init(allocs);
    allocator = countingAllocator.allocator();

    const size = logicSize.scale(info.scale);
    sk.app.run(.{
        .window_title = info.title,
        .width = @as(i32, @intFromFloat(size.x)),
        .height = @as(i32, @intFromFloat(size.y)),
        .init_cb = windowInit,
        .event_cb = windowEvent,
        .frame_cb = windowFrame,
        .cleanup_cb = windowDeinit,
    });
}

export fn windowInit() void {
    clientSize = .init(sk.app.widthf(), sk.app.heightf());
    ratio = clientSize.div(logicSize);
    assets.init(allocator);
    gpu.init();
    math.setRandomSeed(timer.read());
    call(root, "init", .{});
}

pub var mouseMoved: bool = false;
pub var mousePosition: math.Vector = .zero;

export fn windowEvent(event: ?*const Event) void {
    if (event) |ev| {
        input.event(ev);
        if (ev.type == .MOUSE_MOVE) {
            mouseMoved = true;
            const pos = input.mousePosition.sub(displayArea.min);
            mousePosition = pos.mul(logicSize).div(displayArea.size);
        } else if (ev.type == .RESIZED) {
            clientSize = .init(sk.app.widthf(), sk.app.heightf());
            ratio = clientSize.div(logicSize);
        }
        call(root, "event", .{ev});
    }
}

pub fn keepAspectRatio() void {
    const minSize = logicSize.scale(@min(ratio.x, ratio.y));
    const pos = clientSize.sub(minSize).scale(0.5);
    displayArea = .init(pos, minSize);
    sk.gfx.applyViewportf(pos.x, pos.y, minSize.x, minSize.y, true);
}

pub var frameRate: u32 = 0;
pub var frameDeltaPerSecond: f32 = 0;
pub var usedDeltaPerSecond: f32 = 0;

var frameRateTime: u64 = 0;
var frameRateCount: u64 = 0;
var usedDelta: u64 = 0;

const smoothFrameTime: [4]f32 = .{
    @as(f32, 1) / 30, // 30 帧
    @as(f32, 1) / 60, // 60 帧
    @as(f32, 1) / 144, // 144 帧
    @as(f32, 1) / 240, // 240 帧
};
pub var currentSmoothTime: f32 = 0;
var lastTime: u64 = 0;

export fn windowFrame() void {
    const start = timer.read(); // 当前帧的起始时间
    const deltaNano: f32 = @floatFromInt(start - lastTime);
    const delta: f32 = deltaNano / std.time.ns_per_s;

    if (start > frameRateTime + std.time.ns_per_s) { // 一秒统计一次
        frameRateTime = start;
        frameRate = @intCast(frameCount() - frameRateCount);
        frameRateCount = frameCount();
        frameDeltaPerSecond = delta * 1000;
        const deltaUsed: f32 = @floatFromInt(usedDelta);
        usedDeltaPerSecond = deltaUsed / std.time.ns_per_ms;
    }

    sk.fetch.dowork();

    const threshold = 0.002; // 帧平滑阈值，毫秒
    if (@abs(currentSmoothTime - delta) > threshold) {
        // 超过误差，重新平滑时间
        for (smoothFrameTime) |time| {
            if (@abs(time - delta) < threshold) {
                currentSmoothTime = time;
                break;
            }
        } else currentSmoothTime = delta; // 没有找到平滑的时间
    }

    call(root, "frame", .{currentSmoothTime});
    input.lastKeyState = input.keyState;
    input.lastMouseState = input.mouseState;
    input.anyRelease = false;
    mouseMoved = false;

    // 执行更新和渲染消耗的时间，单位为纳秒
    usedDelta = timer.read() - start;
    lastTime = start; // 记录上一帧的时间
}

export fn windowDeinit() void {
    call(root, "deinit", .{});
    sk.gfx.shutdown();
    assets.deinit();
}

pub fn frameCount() u64 {
    return sk.app.frameCount();
}

pub fn relativeTime() u64 {
    return timer.read();
}

pub fn statFileTime(path: [:0]const u8) i64 {
    const file = std.fs.cwd().openFile(path, .{}) catch return 0;
    defer file.close();

    const stat = file.stat() catch return 0;
    return @intCast(stat.mtime);
}

pub fn readAll(path: [:0]const u8, content: []u8) ![]u8 {
    if (@import("builtin").target.os.tag == .emscripten) {
        const len = @import("c.zig").em.em_js_file_load(path.ptr, //
            content.ptr, @intCast(content.len));
        if (len == 0) return error.FileNotFound;

        const value = @import("c.zig").em.my_add(1, 1);
        _ = value;

        return content[0..@as(usize, @intCast(len))];
    }
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const bytes = try file.readAll(content);
    return content[0..bytes];
}

pub fn saveAll(path: [:0]const u8, content: []const u8) !void {
    if (@import("builtin").target.os.tag == .emscripten) {
        return @import("c.zig").em.em_js_file_save(path.ptr, //
            content.ptr, @intCast(content.len));
    }

    const cwd = std.fs.cwd();

    if (std.fs.path.dirname(path)) |dir| {
        try cwd.makePath(dir);
    }

    var file = cwd.openFile(path, .{ .mode = .write_only }) //
        catch |err| switch (err) {
            error.FileNotFound => try cwd.createFile(path, .{}),
            else => return err,
        };
    defer file.close();

    try file.writeAll(content);
}

pub fn alloc(comptime T: type, n: usize) []T {
    return allocator.alloc(T, n) catch @panic("out of memory");
}

pub fn dupe(comptime T: type, m: []const T) []T {
    return allocator.dupe(T, m) catch @panic("out of memory");
}

pub fn free(memory: anytype) void {
    return allocator.free(memory);
}

pub fn exit() void {
    sk.app.requestQuit();
}

pub fn isAnyRelease() bool {
    return input.anyRelease;
}

pub fn drawCenter(str: text.String, y: f32, option: text.Option) void {
    text.drawCenter(str, logicSize.mul(.init(0.5, y)), option);
}

pub const File = assets.File;
pub const loadTexture = assets.loadTexture;
pub const playSound = audio.playSound;
pub const playMusic = audio.playMusic;
pub const stopMusic = audio.stopMusic;
pub const random = math.random;

pub const isKeyDown = input.isKeyDown;
pub const isAnyKeyDown = input.isAnyKeyDown;
pub const isKeyPress = input.isKeyPress;
pub const isAnyKeyPress = input.isAnyKeyPress;
pub const isKeyRelease = input.isKeyRelease;
pub const isAnyKeyRelease = input.isAnyKeyRelease;

pub const isMouseDown = input.isMouseDown;
pub const isMousePress = input.isMousePress;
pub const isMouseRelease = input.isMouseRelease;
pub const isAnyMouseRelease = input.isAnyMouseRelease;

pub const initFont = font.init;
pub const initText = text.init;
