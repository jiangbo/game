const std = @import("std");

const sk = @import("sokol");
const c = @import("c.zig");
const graphics = @import("graphics.zig");
const audio = @import("audio.zig");

const Image = graphics.Image;
const Path = [:0]const u8;

pub var allocator: std.mem.Allocator = undefined;
pub var skAllocator: sk.gfx.Allocator = undefined;
var imageCache: std.AutoHashMapUnmanaged(Id, graphics.Image) = .empty;

pub fn init(allocator1: std.mem.Allocator, maxSize: usize) void {
    allocator = allocator1;
    skAllocator = .{ .alloc_fn = sk_alloc, .free_fn = sk_free };

    sk.fetch.setup(.{
        .num_lanes = fileBuffer.len,
        .logger = .{ .func = sk.log.func },
        .allocator = @bitCast(skAllocator),
    });
    for (&fileBuffer) |*buffer| buffer.* = oomAlloc(u8, maxSize);
}

fn sk_alloc(len: usize, _: ?*anyopaque) callconv(.c) ?*anyopaque {
    const slice = oomAlloc(u8, len + @sizeOf(usize));
    std.mem.bytesAsValue(usize, slice[0..@sizeOf(usize)]).* = len;
    return slice.ptr + @sizeOf(usize);
}

fn sk_free(ptr: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const lenPtr = @as([*]u8, @ptrCast(ptr.?)) - @sizeOf(usize);
    const len = std.mem.bytesToValue(usize, lenPtr[0..@sizeOf(usize)]);
    free(lenPtr[0 .. len + @sizeOf(usize)]);
}

pub fn deinit() void {
    imageCache.deinit(allocator);
    Texture.cache.deinit(allocator);
    Sound.cache.deinit(allocator);
    Music.deinit();
    File.deinit();
    sk.fetch.shutdown();
    for (&fileBuffer) |buffer| free(buffer);
}

pub fn oomAlloc(comptime T: type, n: usize) []T {
    return allocator.alloc(T, n) catch oom();
}

pub fn oomDupe(comptime T: type, m: []const T) []T {
    return allocator.dupe(T, m) catch oom();
}

pub fn free(memory: anytype) void {
    return allocator.free(memory);
}

pub fn oom() noreturn {
    @panic("out of memory");
}

pub fn loadImage(path: Path, size: graphics.Vector2) Image {
    const entry = imageCache.getOrPut(allocator, id(path)) catch oom();
    if (!entry.found_existing) {
        const texture = Texture.load(path);
        entry.value_ptr.* = .{ .texture = texture, .size = size };
    }
    return entry.value_ptr.*;
}

pub fn loadSound(path: Path, loop: bool) ?audio.Sound {
    return Sound.load(path, loop);
}

pub fn loadMusic(path: Path, loop: bool) ?*c.stbAudio.Audio {
    return Music.load(path, loop);
}

pub const Id = u32;
pub fn id(name: []const u8) Id {
    return std.hash.Fnv1a_32.hash(name);
}

pub fn loadAtlas(atlas: graphics.Atlas) void {
    const size: u32 = @intCast(atlas.images.len + 1); // 多包含一张图集
    imageCache.ensureUnusedCapacity(allocator, size) catch oom();
    var image = loadImage(atlas.imagePath, atlas.size);

    for (atlas.images) |atlasImage| {
        image.offset = atlasImage.rect.min;
        image.size = atlasImage.rect.size;
        imageCache.putAssumeCapacity(atlasImage.id, image);
    }
}

pub fn createWhiteImage(comptime key: [:0]const u8) Image {
    const data: [4]u8 = @splat(0xFF);
    const image = Texture.makeImage(1, 1, &data);
    const view = sk.gfx.makeView(.{ .texture = .{ .image = image } });
    Texture.cache.put(allocator, key, view) catch oom();
    imageCache.put(allocator, comptime id(key), .{
        .texture = view,
        .area = .init(.zero, .init(1, 1)),
    }) catch oom();
    return imageCache.get(comptime id(key)).?;
}

pub fn getImage(imageId: Id) graphics.Image {
    return imageCache.get(imageId).?;
}

pub const Icon = c.stbImage.Image;
const IconHandler = fn (u64, Icon) void;
pub fn loadIcon(path: Path, handle: u64, handler: IconHandler) void {
    _ = File.load(path, handle, struct {
        fn callback(response: Response) []const u8 {
            const icon = c.stbImage.loadFromMemory(response.data);
            defer c.stbImage.unload(icon);
            handler(response.index, icon);
            return oomDupe(u8, icon.data);
        }
    }.callback);
}

const Texture = struct {
    var cache: std.AutoHashMapUnmanaged(Id, sk.gfx.View) = .empty;

    fn load(path: Path) sk.gfx.View {
        const view = sk.gfx.allocView();
        cache.put(allocator, id(path), view) catch oom();
        _ = File.load(path, view.id, handler);
        return view;
    }

    fn handler(response: Response) []const u8 {
        const data = response.data;

        const img = c.stbImage.loadFromMemory(data);
        defer c.stbImage.unload(img);
        const view: sk.gfx.View = .{ .id = @intCast(response.index) };

        sk.gfx.initView(view, .{ .texture = .{
            .image = makeImage(img.width, img.height, img.data),
        } });
        return &.{};
    }

    fn makeImage(w: i32, h: i32, data: anytype) sk.gfx.Image {
        return sk.gfx.makeImage(.{
            .width = w,
            .height = h,
            .data = init: {
                var imageData = sk.gfx.ImageData{};
                imageData.mip_levels[0] = sk.gfx.asRange(data);
                break :init imageData;
            },
        });
    }
};

const Sound = struct {
    var cache: std.AutoHashMapUnmanaged(Id, audio.Sound) = .empty;

    fn load(path: Path, loop: bool) ?audio.Sound {
        if (cache.get(id(path))) |value| return value;

        _ = File.load(path, if (loop) 1 else 0, handler);
        return null;
    }

    fn handler(response: Response) []const u8 {
        const data = response.data;

        const stbAudio = c.stbAudio.loadFromMemory(data);
        defer c.stbAudio.unload(stbAudio);
        const info = c.stbAudio.getInfo(stbAudio);

        const channels: i32 = @intCast(info.channels);
        const size = c.stbAudio.getSampleCount(stbAudio) * channels;
        const samples = oomAlloc(f32, @intCast(size));
        _ = c.stbAudio.fillSamples(stbAudio, samples, channels);

        cache.put(allocator, id(response.path), .{
            .samples = samples,
            .channels = @intCast(channels),
        }) catch oom();
        _ = audio.playSoundOption(response.path, response.index == 1);
        return std.mem.sliceAsBytes(samples);
    }
};

const Music = struct {
    var cache: std.AutoHashMapUnmanaged(Id, *c.stbAudio.Audio) = .empty;

    fn load(path: Path, loop: bool) ?*c.stbAudio.Audio {
        if (cache.get(id(path))) |value| return value;

        _ = File.load(path, if (loop) 1 else 0, handler);
        return null;
    }

    fn handler(response: Response) []const u8 {
        const data = oomDupe(u8, response.data);
        const stbAudio = c.stbAudio.loadFromMemory(data);
        cache.put(allocator, id(response.path), stbAudio) catch oom();
        audio.playMusicOption(response.path, response.index == 1);
        return data;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |v| c.stbAudio.unload(v.*);
        cache.deinit(allocator);
    }
};

const SkCallback = *const fn ([*c]const sk.fetch.Response) callconv(.C) void;
pub const Response = struct {
    index: u64 = undefined,
    path: [:0]const u8,
    data: []const u8 = &.{},
};

var fileBuffer: [4][]u8 = undefined;
pub const File = struct {
    const FileState = enum { init, loading, loaded, handled };
    const Handler = *const fn (Response) []const u8;

    const FileCache = struct {
        state: FileState = .init,
        index: u64,
        managed: []const u8 = &.{},
        handler: Handler = undefined,
    };

    var cache: std.AutoHashMapUnmanaged(Id, FileCache) = .empty;

    pub fn load(path: Path, index: u64, handler: Handler) *FileCache {
        const entry = cache.getOrPut(allocator, id(path)) catch oom();
        if (entry.found_existing) return entry.value_ptr;

        entry.value_ptr.* = .{ .index = index, .handler = handler };

        std.log.info("loading {s}", .{path});
        _ = sk.fetch.send(.{
            .path = path,
            .callback = callback,
        });

        entry.value_ptr.state = .loading;
        return entry.value_ptr;
    }

    fn callback(responses: [*c]const sk.fetch.Response) callconv(.c) void {
        const res = responses[0];
        if (res.failed) {
            const msg = "assets load failed, path: {s}, error code: {}";
            std.debug.panic(msg, .{ res.path, res.error_code });
        }
        if (res.dispatched) {
            const buffer = sk.fetch.asRange(fileBuffer[res.lane]);
            sk.fetch.bindBuffer(res.handle, buffer);
            return;
        }

        const path = std.mem.span(res.path);
        std.log.info("loaded from: {s}", .{path});

        const value = cache.getPtr(id(path)) orelse return;
        const data = @as([*]const u8, @ptrCast(res.data.ptr));
        const response: Response = .{
            .index = value.index,
            .path = path,
            .data = data[0..res.data.size],
        };

        value.state = .loaded;
        value.managed = value.handler(response);
        value.state = .handled;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.managed);
        cache.deinit(allocator);
    }
};
