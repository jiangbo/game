const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const com = @import("component.zig");

pub const maps = [_]tiled.Map{
    @import("zon/title.zon"),
    @import("zon/level1.zon"),
    @import("zon/level2.zon"),
};
var data: *const tiled.Map = &maps[0];
const Animation = struct {
    position: zhu.Vector2,
    size: zhu.Vector2,
    value: zhu.graphics.Animation,
    extend: tiled.ObjectExtend = .{},
};
var animations: std.ArrayList(Animation) = .empty;
var tileVertexes: std.ArrayList(batch.Vertex) = .empty;

pub const PlaceKind = enum { melee, ranged };
pub const Place = struct {
    position: zhu.Vector2,
    size: zhu.Vector2,
    kind: PlaceKind,
    entity: ?zhu.ecs.Entity = null,
};

pub var paths: std.AutoHashMapUnmanaged(u8, com.Path) = .empty;
pub var startPaths: [10]u8 = undefined; // 最多 10 条起始路径
pub var places: std.ArrayList(Place) = .empty;

pub fn init(levelIndex: usize) void {
    data = &maps[levelIndex];
    tiled.backgroundColor = data.backgroundColor;
    @memset(&startPaths, 0);

    for (data.layers) |*layer| {
        if (std.mem.eql(u8, "path", layer.name)) {
            parsePathLayer(layer);
        } else {
            switch (layer.type) {
                .tile => parseTileLayer(layer),
                .object => parseObjectLayer(layer),
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

pub fn deinit() void {
    tileVertexes.clearAndFree(zhu.assets.allocator);
    animations.clearAndFree(zhu.assets.allocator);
    places.clearAndFree(zhu.assets.allocator);
    paths.clearAndFree(zhu.assets.allocator);
}

fn parsePathLayer(layer: *const tiled.Layer) void {
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
                    startPath.* = @intCast(object.gid);
                    break;
                } else unreachable;
            }
        }
        paths.put(zhu.assets.allocator, @intCast(object.gid), path) //
        catch @panic("oom, can't put path");
    }
}

fn parseTileLayer(layer: *const tiled.Layer) void {
    const ts = tiled.getTileSetById(zhu.id("Tilemap.tsj"));
    const tileImage = zhu.assets.getImage(ts.image);

    for (layer.data, 0..) |gid, index| {
        if (gid == 0) continue;

        const x: f32 = @floatFromInt(index % data.width);
        const y: f32 = @floatFromInt(index / data.width);
        var pos = data.tileSize.mul(.xy(x, y));

        var image: zhu.graphics.Image = undefined;
        const tileSetRef = data.getTileSetRefByGid(gid);
        const tileSet = tiled.getTileSetByRef(tileSetRef);
        const localId = gid - tileSetRef.firstGid;

        const tile = tileSet.getTileByLocalId(localId);
        if (tile != null and tile.?.animation.len > 0) {
            image = zhu.assets.getImage(tileSet.image);
            animations.append(zhu.assets.allocator, .{
                .position = pos,
                .size = data.tileSize,
                .value = .init(image, tile.?.animation),
            }) catch @panic("oom, can't append animation");
            continue;
        }

        if (tileSet.columns == 0) { // 单图片瓦片集的列数
            image = zhu.assets.getImage(tile.?.id);
            pos.y = pos.y - image.size.y + data.tileSize.y;
        } else {
            const area = data.tileArea(localId, tileSet.columns);
            image = tileImage.sub(area);
        }

        tileVertexes.append(zhu.assets.allocator, .{
            .position = pos,
            .size = image.size,
            .texturePosition = image.toTexturePosition(),
        }) catch @panic("oom, can't append tile");

        // if (tile) |t| parseProperties(index, t); // 解析碰撞信息
    }
}

fn placeKind(tile: *const tiled.Tile) ?PlaceKind {
    for (tile.properties) |prop| {
        if (!prop.is("place")) continue;
        if (std.mem.eql(u8, prop.value.string, "melee")) return .melee;
        if (std.mem.eql(u8, prop.value.string, "range")) return .ranged;
    } else return null;
}

fn parseObjectLayer(layer: *const tiled.Layer) void {
    for (layer.objects) |object| {
        if (object.gid == 0) {
            std.log.info("gid 0, position: {}", .{object.position});
            continue;
        }

        const tileSetRef = data.getTileSetRefByGid(object.gid);
        const tileSet = tiled.getTileSetByRef(tileSetRef);
        const localId = object.gid - tileSetRef.firstGid;

        const tile = tileSet.getTileByLocalId(localId);

        if (tile == null) {
            std.log.info("tile is null, gid: {}", .{object.gid});
            continue;
        }

        const pos = object.position.addY(-object.size.y);
        if (placeKind(tile.?)) |kind| {
            places.append(zhu.assets.allocator, .{
                .position = pos,
                .size = object.size,
                .kind = kind,
            }) catch @panic("oom, can't append place");
        }

        if (tileSet.columns == 0) {
            const image = zhu.assets.getImage(tile.?.id);
            tileVertexes.append(zhu.assets.allocator, .{
                .position = pos,
                .size = object.size,
                .texturePosition = image.toTexturePosition(),
            }) catch @panic("oom, can't append tile");
        } else {

            // 图片太大，不能合并到图集中，使用临时方案解决。
            const path: ?[:0]const u8 = switch (tileSet.image) {
                672649248 => "assets/textures/Units/Archer.png",
                1853426592 => "assets/textures/Units/Lancer.png",
                1610704809 => "assets/textures/Units/Warrior.png",
                else => null,
            };
            const image = if (path) |p| blk: {
                break :blk zhu.assets.loadImage(p, .zero);
            } else zhu.assets.getImage(tileSet.image);

            animations.append(zhu.assets.allocator, .{
                .position = pos,
                .size = object.size,
                .value = .init(image, tile.?.animation),
                .extend = object.extend,
            }) catch @panic("oom, can't append animation");
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
    batch.currentCommand().texture = batch.whiteImage.texture;
    batch.vertexBuffer.appendSliceAssumeCapacity(tileVertexes.items);

    for (animations.items) |item| {
        const image = item.value.subImage(item.size);
        batch.drawImage(image, item.position, .{
            .flipX = item.extend.flipX,
        });
    }
}
