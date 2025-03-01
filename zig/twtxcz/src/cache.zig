const std = @import("std");
const gfx = @import("graphics.zig");

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    TextureCache.init();
}

pub fn deinit() void {
    TextureCache.deinit();
}

pub const TextureCache = struct {
    const stbi = @import("stbi");
    const Cache = std.StringHashMap(gfx.Texture);

    var cache: Cache = undefined;

    pub fn init() void {
        cache = Cache.init(allocator);
        stbi.init(allocator);
    }

    pub fn load(path: [:0]const u8) ?gfx.Texture {
        const entry = cache.getOrPut(path) catch |e| {
            std.log.err("texture cache allocate error: {}", .{e});
            return null;
        };
        if (entry.found_existing) return entry.value_ptr.*;

        std.log.info("loading texture from: {s}", .{path});
        var image = stbi.Image.loadFromFile(path, 4) catch |e| {
            std.log.err("loading image error: {}", .{e});
            return null;
        };

        defer image.deinit();

        const texture = gfx.Texture.init(image.width, image.height, image.data);
        entry.value_ptr.* = texture;
        entry.key_ptr.* = allocator.dupe(u8, path) catch unreachable;
        return texture;
    }

    pub fn deinit() void {
        stbi.deinit();
        var keyIter = cache.keyIterator();
        while (keyIter.next()) |key| allocator.free(key.*);
        cache.deinit();
    }
};
