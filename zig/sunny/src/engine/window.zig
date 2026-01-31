const std = @import("std");
const builtin = @import("builtin");

const sk = @import("sokol");
const math = @import("math.zig");
const assets = @import("assets.zig");
const audio = @import("audio.zig");
const input = @import("input.zig");
const text = @import("text.zig");
const gpu = @import("gpu.zig");
const graphics = @import("graphics.zig");
const batch = @import("batch.zig");

pub const Event = sk.app.Event;

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

/// 缩放模式枚举
pub const ScaleEnum = enum {
    /// 无缩放，使用原始尺寸
    none,
    /// 拉伸缩放，忽略宽高比填满屏幕
    stretch,
    /// 适配缩放，保持宽高比可能有黑边
    fit,
    /// 填充缩放，保持宽高比可能超出屏幕
    fill,
    /// 整数缩放，整数倍数（无滤镜失真）
    integer,
};

pub const WindowInfo = struct {
    title: [:0]const u8, // 窗口标题
    size: math.Vector, // 窗口大小
    logicSize: ?math.Vector = null, // 逻辑大小，默认和窗口大小相同
    scaleEnum: ScaleEnum = .stretch, // 缩放模式
    disableIME: bool = true, // 禁用输入法
    alignment: math.Vector = .center, // 对齐方式
};

pub fn call(object: anytype, comptime name: []const u8, args: anytype) void {
    if (@hasDecl(object, name)) @call(.auto, @field(object, name), args);
}

pub var size: math.Vector = .zero;
pub var clientSize: math.Vector = .zero;
pub var viewRect: math.Rect = undefined;
pub var countingAllocator: CountingAllocator = undefined;
pub var alignment: math.Vector2 = .center; // 默认居中
var scaleEnum: ScaleEnum = .stretch; // 当前缩放模式
var timer: std.time.Timer = undefined;

pub extern "Imm32" fn ImmDisableIME(i32) std.os.windows.BOOL;

const root = @import("root");
pub fn run(allocs: std.mem.Allocator, info: WindowInfo) void {
    timer = std.time.Timer.start() catch unreachable;
    size = info.logicSize orelse info.size;
    viewRect = .init(.zero, size);
    alignment = info.alignment;
    scaleEnum = info.scaleEnum;
    countingAllocator = CountingAllocator.init(allocs);
    assets.init(countingAllocator.allocator());

    if (info.disableIME and builtin.os.tag == .windows) {
        _ = ImmDisableIME(-1);
    }

    sk.app.run(.{
        .window_title = info.title,
        .width = @intFromFloat(info.size.x),
        .height = @intFromFloat(info.size.y),
        .init_cb = windowInit,
        .event_cb = windowEvent,
        .frame_cb = windowFrame,
        .cleanup_cb = windowDeinit,
    });
}

export fn windowInit() void {
    computeViewRect();
    gpu.init();
    math.setRandomSeed(timer.read());
    call(root, "init", .{});
}

pub var mouseMoved: bool = false;
pub var mousePosition: math.Vector = .zero;
pub var resized: bool = false;

export fn windowEvent(event: ?*const Event) void {
    if (event) |ev| {
        input.event(ev);
        if (ev.type == .MOUSE_MOVE) {
            mouseMoved = true;
            const position = input.mousePosition.sub(viewRect.min);
            mousePosition = position.mul(size).div(viewRect.size);
        } else if (ev.type == .RESIZED) resized = true;

        call(root, "event", .{ev});
    }
}

pub fn computeViewRect() void {
    clientSize = .xy(sk.app.widthf(), sk.app.heightf());
    const ratio = clientSize.div(size);
    switch (scaleEnum) {
        .none => {
            viewRect = .init(clientSize.sub(size).mul(alignment), size);
        },
        .stretch => viewRect = .init(.zero, clientSize),
        .fit => {
            const minSize = size.scale(@min(ratio.x, ratio.y));
            const position = clientSize.sub(minSize).mul(alignment);
            viewRect = .init(position, minSize);
        },
        .fill => {
            const maxSize = size.scale(@max(ratio.x, ratio.y));
            const position = clientSize.sub(maxSize).mul(alignment);
            viewRect = .init(position, maxSize);
        },
        .integer => {
            const intSize = size.scale(@trunc(@min(ratio.x, ratio.y)));
            const position = clientSize.sub(intSize).mul(alignment);
            viewRect = .init(position, intSize);
        },
    }
}

var frameRate: u32 = 0;
var frameDeltaPerSecond: f32 = 0;
var usedDeltaPerSecond: f32 = 0;

var frameRateTime: u64 = 0;
var frameRateCount: u64 = 0;
var usedDelta: u64 = 0;

const smoothFrameTime: [4]f32 = .{
    @as(f32, 1) / 30, // 30 帧
    @as(f32, 1) / 60, // 60 帧
    @as(f32, 1) / 144, // 144 帧
    @as(f32, 1) / 240, // 240 帧
};
var currentSmoothTime: f32 = 0;
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

    if (currentSmoothTime > 0.1) currentSmoothTime = 0.1;
    if (resized) computeViewRect();
    call(root, "frame", .{currentSmoothTime});
    input.lastKeyState = input.keyState;
    input.lastMouseState = input.mouseState;
    input.anyRelease = false;
    mouseMoved = false;

    // 执行更新和渲染消耗的时间，单位为纳秒
    usedDelta = timer.read() - start;
    lastTime = start; // 记录上一帧的时间
    resized = false;
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

var debutTextCount: u32 = 0;
pub fn drawDebugInfo() void {
    var buffer: [1024]u8 = undefined;
    const format =
        \\后端：{s}
        \\帧率：{}
        \\平滑：{d:.2}
        \\帧时：{d:.2}
        \\用时：{d:.2}
        \\显存：{}
        \\常量：{}
        \\绘制：{}
        \\图片：{}
        \\文字：{}
        \\内存：{}
        \\鼠标：{d:.2}，{d:.2}
    ;

    const stats = graphics.queryFrameStats();
    const t = text.format(&buffer, format, .{
        @tagName(graphics.queryBackend()),
        frameRate,
        currentSmoothTime * 1000,
        frameDeltaPerSecond,
        usedDeltaPerSecond,
        stats.size_append_buffer + stats.size_update_buffer,
        stats.size_apply_uniforms,
        stats.num_draw,
        batch.imageDrawCount(),
        // Debug 信息本身的次数也应该统计进去
        graphics.textCount + debutTextCount,
        countingAllocator.used,
        mousePosition.x,
        mousePosition.y,
    });

    debutTextCount = text.computeTextCount(t);
    text.drawColor(t, .xy(10, 10), .green);
}

pub fn statFileTime(path: [:0]const u8) i64 {
    const file = std.fs.cwd().openFile(path, .{}) catch return 0;
    defer file.close();

    const stat = file.stat() catch return 0;
    return @intCast(stat.mtime);
}

pub fn readBuffer(path: [:0]const u8, buffer: []u8) ![]u8 {
    if (@import("builtin").target.os.tag == .emscripten) {
        const value = @import("c.zig").em.my_add(1, 1);
        _ = value; // 防止编译器优化掉，目前不清楚为什么要加这个方法才生效
        const len = try readFromJs(path, &buffer);
        // 长度大于0，读完了内容，直接分配返回。
        if (len > 0) return buffer[0..@intCast(len)];
        // 长度小于0，没有读完，太长了。
        return error.BufferTooSmall;
    }
    return std.fs.cwd().readFile(path, buffer);
}

pub fn readAll(path: [:0]const u8) ![]u8 {
    if (@import("builtin").target.os.tag == .emscripten) {
        const value = @import("c.zig").em.my_add(1, 1);
        _ = value; // 防止编译器优化掉，目前不清楚为什么要加这个方法才生效
        var buffer: [1024]u8 = undefined;
        const len = try readFromJs(path, &buffer);
        // 长度大于0，读完了内容，直接分配返回。
        if (len > 0) return assets.oomDupe(u8, buffer[0..@intCast(len)]);

        // 长度小于0，没有读完，太长了，分配更大的空间再读一次。
        const large = assets.oomAlloc(u8, buffer.len + @as(usize, @abs(len)));
        _ = readFromJs(path, large);
        return large;
    }
    const max = 1024 * 1024;
    return try std.fs.cwd().readFileAlloc(assets.allocator, path, max);
}

fn readFromJs(path: [:0]const u8, content: []u8) !i32 {
    const len = @import("c.zig").em.em_js_file_load(path.ptr, //
        content.ptr, @intCast(content.len));
    if (len == 0) return error.FileNotFound;
    return len;
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

pub fn exit() void {
    sk.app.requestQuit();
}

pub fn isAnyRelease() bool {
    return input.anyRelease;
}

pub const Cursor = sk.app.MouseCursor;
pub const useMouseIcon = sk.app.setMouseCursor;
pub const CursorDesc = extern struct {
    cursor: Cursor = .CUSTOM_1,
    offset: extern struct { x: i16 = 0, y: i16 = 0 } = .{},
    comptime {
        std.debug.assert(@sizeOf(@This()) == @sizeOf(u64));
    }
};
pub fn bindMouseIcon(path: [:0]const u8, desc: CursorDesc) void {
    assets.loadIcon(path, @bitCast(desc), mouseCallback);
}

fn mouseCallback(handle: u64, icon: assets.Icon) void {
    const cursorDesc: CursorDesc = @bitCast(handle);
    _ = sk.app.bindMouseCursorImage(cursorDesc.cursor, .{
        .pixels = @bitCast(sk.gfx.asRange(icon.data)),
        .width = icon.width,
        .height = icon.height,
        .cursor_hotspot_x = cursorDesc.offset.x,
        .cursor_hotspot_y = cursorDesc.offset.y,
    });
}

pub fn bindAndUseMouseIcon(path: [:0]const u8, desc: CursorDesc) void {
    assets.loadIcon(path, @bitCast(desc), struct {
        fn callback(handle: u64, icon: assets.Icon) void {
            mouseCallback(handle, icon);
            const cursorDesc: CursorDesc = @bitCast(handle);
            useMouseIcon(cursorDesc.cursor);
        }
    }.callback);
}

pub fn useWindowIcon(path: [:0]const u8) void {
    assets.loadIcon(path, 0, struct {
        fn callback(icon: assets.Icon) void {
            var desc: sk.app.IconDesc = .{};
            desc.images[0] = .{
                .pixels = @bitCast(sk.gfx.asRange(icon.data)),
                .width = icon.width,
                .height = icon.height,
            };
            sk.app.setIcon(desc);
        }
    }.callback);
}

pub fn drawCenter(str: text.String, y: f32, option: text.Option) void {
    text.drawCenter(str, size.mul(.init(0.5, y)), option);
}

pub const isKeyDown = input.isKeyDown;
pub const isAnyKeyDown = input.isAnyKeyDown;
pub const isKeyPressed = input.isKeyPressed;
pub const isAnyKeyPressed = input.isAnyKeyPressed;
pub const isKeyReleased = input.isKeyReleased;
pub const isAnyKeyReleased = input.isAnyKeyReleased;

pub const isMouseDown = input.isMouseDown;
pub const isMousePressed = input.isMousePressed;
pub const isMouseReleased = input.isMouseReleased;
pub const isAnyMouseReleased = input.isAnyMouseReleased;

pub const initText = text.initBitMapFont;
