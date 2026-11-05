const ecs = @import("ecs");
const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const com = @import("component.zig");

const tileSets: []const tiled.TileSet = @import("zon/tile.zon");
pub const maps = tiled.bind(tileSets, &.{
    @import("zon/title.zon"),
    @import("zon/level1.zon"),
    @import("zon/level2.zon"),
});
var data: *const tiled.Map = &maps[0];
const Animation = struct {
    position: zhu.Vector2,
    size: zhu.Vector2,
    value: zhu.graphics.Animation,
    extend: tiled.ObjectExtend = .{},
};
var animations: std.ArrayList(Animation) = .empty;
const TileImage = struct {
    position: zhu.Vector2,
    image: zhu.Image,
    size: ?zhu.Vector2 = null,
};
var tiles: std.ArrayList(TileImage) = .empty;

pub const PlaceKind = enum { melee, ranged };
pub const Place = struct {
    position: zhu.Vector2,
    size: zhu.Vector2,
    kind: PlaceKind,
    entity: ?ecs.Entity = null,
};

pub var paths: std.AutoHashMapUnmanaged(u8, com.Path) = .empty;
pub var startPaths: [10]u8 = undefined; // 最多 10 条起始路径
pub var places: std.ArrayList(Place) = .empty;

pub fn init(allocator: zhu.Allocator, levelIndex: usize) void {
    data = &maps[levelIndex];
    _ = zhu.loadImage("textures/Units/Archer.png", .xy(1536, 384), .{});
    _ = zhu.loadImage("textures/Units/Lancer.png", .xy(3840, 640), .{});
    _ = zhu.loadImage("textures/Units/Warrior.png", .xy(1536, 576), .{});
    @memset(&startPaths, 0);

    for (data.layers) |*layer| {
        if (std.mem.eql(u8, "path", layer.name)) {
            parsePathLayer(allocator, layer);
        } else {
            switch (layer.type) {
                .tile => parseTileLayer(allocator, layer),
                .object => parseObjectLayer(allocator, layer),
                else => unreachable,
            }
        }
    }

    std.mem.sortUnstable(Animation, animations.items, {}, struct {
        fn lessThan(_: void, a: Animation, b: Animation) bool {
            return a.position.y < b.position.y;
        }
    }.lessThan);
}

pub fn deinit(allocator: zhu.Allocator) void {
    tiles.clearAndFree(allocator);
    animations.clearAndFree(allocator);
    places.clearAndFree(allocator);
    paths.clearAndFree(allocator);
}

fn parsePathLayer(allocator: zhu.Allocator, layer: *const tiled.Layer) void {
    for (layer.objects) |object| {
        var path: com.Path = .{ .point = object.position };
        for (object.properties) |prop| {
            if (prop.is("next")) {
                path.next = @intCast(prop.value.object);
            } else if (prop.is("next2")) {
                path.next2 = @intCast(prop.value.object);
            } else if (prop.is("start")) {
                for (&startPaths) |*startPath| {
                    if (startPath.* != 0) continue;
                    startPath.* = @intCast(object.id);
                    break;
                } else unreachable;
            }
        }
        paths.put(allocator, @intCast(object.id), path) //
        catch @panic("oom, can't put path");
    }
}

fn parseTileLayer(allocator: zhu.Allocator, layer: *const tiled.Layer) void {
    for (layer.data, 0..) |gid, index| {
        if (gid == 0) continue;
        var pos = data.grid.indexToWorld(index);
        if (data.getAnimation(gid)) |animation| {
            animations.append(allocator, .{
                .position = pos,
                .size = data.grid.cellSize(),
                .value = animation,
            }) catch @panic("oom");
        } else {
            const image = data.getImage(gid).?;
            pos.y += data.grid.cellSize().y - image.size.y;
            tiles.append(allocator, .{
                .position = pos,
                .image = image,
            }) catch @panic("oom");
        }
    }
}

fn placeKind(tile: *const tiled.Tile) ?PlaceKind {
    for (tile.properties) |prop| {
        if (!prop.is("place")) continue;
        if (std.mem.eql(u8, prop.value.string, "melee")) return .melee;
        if (std.mem.eql(u8, prop.value.string, "range")) return .ranged;
    } else return null;
}

fn parseObjectLayer(allocator: zhu.Allocator, layer: *const tiled.Layer) void {
    for (layer.objects) |object| {
        if (object.gid == 0) {
            std.log.info("gid 0, position: {}", .{object.position});
            continue;
        }

        const tile = data.getTile(object.gid) orelse continue;

        const pos = object.position.addY(-object.size.y);
        if (placeKind(tile)) |kind| {
            places.append(allocator, .{
                .position = pos,
                .size = object.size,
                .kind = kind,
            }) catch @panic("oom, can't append place");
        }

        if (data.getAnimation(object.gid)) |animation| {
            animations.append(allocator, .{
                .position = pos,
                .size = object.size,
                .value = animation,
                .extend = object.extend,
            }) catch @panic("oom");
        } else {
            const image = data.getImage(object.gid).?;
            tiles.append(allocator, .{
                .position = pos,
                .image = image,
                .size = object.size,
            }) catch @panic("oom");
        }
    }
}

/// 查找位置匹配且未被占用的出击区域
pub fn findPlace(kind: PlaceKind, pos: zhu.Vector2) ?usize {
    for (places.items, 0..) |place, i| {
        if (place.entity != null or place.kind != kind) continue;
        const rect: zhu.Rect = .init(place.position, place.size);
        if (rect.contains(pos)) return i;
    } else return null;
}

pub fn update(delta: f32) void {
    for (animations.items) |*item| _ = item.value.update(delta);
}

pub fn draw() void {
    for (tiles.items) |tile| {
        batch.drawImage(tile.image, tile.position, .{ .size = tile.size });
    }

    for (animations.items) |item| {
        const image = item.value.subImage();
        batch.drawImage(image, item.position, .{
            .uvRect = image.uvFlip(item.extend.flipX, item.extend.flipY),
            .size = item.size,
        });
    }
}

pub fn backgroundColor() zhu.Color {
    return data.backgroundColor orelse .black;
}
