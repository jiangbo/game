const std = @import("std");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const c = @import("c.zig");

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn deinit() void {
    Texture.deinit();
    TextureSlice.deinit();
    RectangleSlice.deinit();
    Sound.deinit();
}

pub const Texture = struct {
    var cache: std.StringHashMapUnmanaged(gfx.Texture) = .empty;

    pub fn load(path: [:0]const u8) gfx.Texture {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        std.log.info("loading texture from: {s}", .{path});
        const image = c.stbImage.load(path) catch unreachable;
        defer c.stbImage.unload(image);

        const texture = gfx.Texture.init(image.width, image.height, image.data);
        entry.value_ptr.* = texture;
        entry.key_ptr.* = allocator.dupe(u8, path) catch unreachable;
        return texture;
    }

    pub fn loadSlice(textures: []gfx.Texture, comptime pathFmt: []const u8, from: u8) void {
        std.log.info("loading texture slice : {s}", .{pathFmt});

        var buffer: [128]u8 = undefined;
        for (from..from + textures.len) |index| {
            const path = std.fmt.bufPrintZ(&buffer, pathFmt, .{index});

            const texture = Texture.load(path catch unreachable);
            textures[index - from] = texture;
        }
    }

    pub fn deinit() void {
        var keyIter = cache.keyIterator();
        while (keyIter.next()) |key| allocator.free(key.*);
        cache.deinit(allocator);
    }
};

pub const TextureSlice = struct {
    var cache: std.StringHashMapUnmanaged([]gfx.Texture) = .empty;

    pub fn load(comptime pathFmt: []const u8, from: u8, len: u8) []const gfx.Texture {
        const entry = cache.getOrPut(allocator, pathFmt) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        const textures = allocator.alloc(gfx.Texture, len) catch unreachable;

        Texture.loadSlice(textures, pathFmt, from);
        entry.value_ptr.* = textures;
        entry.key_ptr.* = allocator.dupe(u8, pathFmt) catch unreachable;
        return textures;
    }

    pub fn deinit() void {
        var iterator = cache.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        cache.deinit(allocator);
    }
};

pub const RectangleSlice = struct {
    var cache: std.StringHashMapUnmanaged([]math.Rectangle) = .empty;

    pub fn load(path: []const u8, count: u8) []math.Rectangle {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        const slice = allocator.alloc(math.Rectangle, count) catch unreachable;
        entry.value_ptr.* = slice;
        return slice;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.*);
        cache.deinit(allocator);
    }
};

const audio = @import("audio.zig");
pub const Sound = struct {
    var cache: std.StringHashMapUnmanaged(audio.Sound) = .empty;

    pub fn load(path: [:0]const u8) audio.Sound {
        const entry = cache.getOrPut(allocator, path) catch unreachable;
        if (entry.found_existing) return entry.value_ptr.*;

        std.log.info("loading audio from: {s}", .{path});
        const stbAudio = c.stbAudio.load(path) catch unreachable;
        defer c.stbAudio.unload(stbAudio);

        var sound: audio.Sound = .{ .source = undefined };
        const info = c.stbAudio.getInfo(stbAudio);
        sound.channels = @intCast(info.channels);
        sound.sampleRate = @intCast(info.sample_rate);

        const size = c.stbAudio.getSampleCount(stbAudio) * sound.channels;
        sound.source = allocator.alloc(f32, size) catch unreachable;

        _ = c.stbAudio.fillSamples(stbAudio, sound.source, sound.channels);
        entry.value_ptr.* = sound;
        return sound;
    }

    pub fn deinit() void {
        var iterator = cache.valueIterator();
        while (iterator.next()) |value| allocator.free(value.source);
        cache.deinit(allocator);
    }
};
