const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const tiled = zhu.extend.tiled;
const Vector2 = zhu.Vector2;

pub const ObjectEnum = enum(u32) {
    player = zhu.assets.id("textures/Actors/foxy.png"),
    eagle = zhu.assets.id("textures/Actors/eagle-attack.png"),
    frog = zhu.assets.id("textures/Actors/frog.png"),
    opossum = zhu.assets.id("textures/Actors/opossum.png"),
    skull = zhu.assets.id("textures/Props/skulls.png"),
    spike = zhu.assets.id("textures/Props/spikes.png"),
    spikeTop = zhu.assets.id("textures/Props/spikes-top.png"),
    cherry = zhu.assets.id("textures/Items/cherry.png"),
    gem = zhu.assets.id("textures/Items/gem.png"),
};

pub const TileEnum = enum { normal, solid, uniSolid, ladder };

pub const Object = struct {
    type: ObjectEnum,
    initPosition: Vector2 = .zero,
    position: Vector2,
    velocity: Vector2 = .zero,
    size: Vector2,
    object: ?tiled.Object,
};
const tileSets: []const tiled.TileSet = @import("zon/tile.zon");
pub const maps = tiled.bind(tileSets, &.{
    @import("zon/level1.zon"),
    @import("zon/level2.zon"),
});
pub var map = maps[0];
var tileVertexes: std.ArrayList(batch.Vertex) = .empty;
pub var objects: std.ArrayList(Object) = .empty;
var tileStates: []TileEnum = &.{};
var allocator: zhu.Allocator = undefined;

pub var nextLevelArea: ?zhu.Rect = null;

pub fn init(allocator_: zhu.Allocator, level: u8) void {
    allocator = allocator_;

    if (tileStates.len != 0) { // 如果存在之前的数据，则先释放
        allocator.free(tileStates);
        tileVertexes.clearRetainingCapacity();
        objects.clearRetainingCapacity();
        nextLevelArea = null;
    }

    map = maps[level];

    tileStates = allocator.alloc(TileEnum, map.grid.count());
    @memset(tileStates, .normal);
    zhu.camera.bound = map.grid.size();

    for (map.layers) |layer| {
        if (layer.type == .tile) parseTileLayer(&layer) //
        else if (layer.type == .object) parseObjectLayer(&layer);
    }
}

pub fn deinit(allocator_: zhu.Allocator) void {
    objects.deinit(allocator_.raw);
    tileVertexes.deinit(allocator_.raw);
    allocator_.free(tileStates);
}

fn parseTileLayer(layer: *const tiled.Layer) void {
    for (layer.data, 0..) |gid, index| {
        if (gid == 0) continue;

        const width: usize = @intCast(map.grid.width);
        const x: f32 = @floatFromInt(index % width);
        const y: f32 = @floatFromInt(index / width);
        var pos = map.grid.cellSize().mul(.xy(x, y));

        const image = map.getImage(gid).?;
        const tile = map.getTile(gid);
        if (tile) |t| {
            pos.y = pos.y - image.size.y + map.grid.cellSize().y;
            if (tile.?.id == @intFromEnum(ObjectEnum.spike)) {
                parseTileSpike(t, pos);
            }
        }

        tileVertexes.append(allocator.raw, .{
            .position = pos,
            .size = image.size,
            .uvRect = image.uvRect(),
        }) catch @panic("oom, can't append tile");

        if (tile) |t| parseProperties(index, t.*); // 解析碰撞信息
    }
}

fn parseTileSpike(tile: *const tiled.Tile, pos: zhu.Vector2) void {
    const object = tile.objectGroup.?.objects[0];
    objects.append(allocator.raw, .{
        .type = @enumFromInt(tile.id),
        .position = pos,
        .initPosition = pos,
        .size = object.size,
        .object = object,
    }) catch @panic("oom, can't append tile");
}

fn parseProperties(index: usize, tile: tiled.Tile) void {
    for (tile.properties) |property| {
        if (std.mem.eql(u8, property.name, "solid")) {
            if (property.value.get(bool).?) tileStates[index] = .solid;
        } else if (std.mem.eql(u8, property.name, "unisolid")) {
            if (property.value.get(bool).?) tileStates[index] = .uniSolid;
        } else if (std.mem.eql(u8, property.name, "ladder")) {
            if (property.value.get(bool).?) tileStates[index] = .ladder;
        } else tileStates[index] = .normal;
    }
}

fn parseObjectLayer(layer: *const tiled.Layer) void {
    for (layer.objects) |object| {
        if (object.gid == 0) {
            if (object.properties.len != 0) {
                const property = object.properties[0];
                const tag = property.value.get([]const u8).?;
                if (std.mem.eql(u8, property.name, "tag") and
                    std.mem.eql(u8, tag, "next_level"))
                {
                    nextLevelArea = object.rect();
                }
            } else std.log.info("gid 0, position: {}", .{object.position});
            continue;
        }
        const tile = map.getTile(object.gid).?;

        var obj: ?tiled.Object = null;
        if (tile.objectGroup) |group| obj = group.objects[0];
        objects.append(allocator.raw, .{
            .type = @enumFromInt(tile.id),
            .position = object.topLeft(),
            .initPosition = object.topLeft(),
            .size = object.size,
            .object = obj,
        }) catch @panic("oom, can't append tile");
    }
}

pub fn isTouchLadder(pos: Vector2, size: Vector2) bool {
    const topLeft = pos;
    const topRight = pos.addX(size.x);
    const bottomLeft = pos.addY(size.y);
    const bottomRight = pos.add(size);

    return tileStates[tileIndex(topLeft)] == .ladder or
        tileStates[tileIndex(topRight)] == .ladder or
        tileStates[tileIndex(bottomLeft)] == .ladder or
        tileStates[tileIndex(bottomRight)] == .ladder;
}

pub fn isTopLadder(pos: Vector2, size: Vector2) bool {
    const centerX = pos.x + size.x / 2;
    const point = zhu.Vector2.xy(centerX, pos.y + size.y);
    return tileStates[tileIndex(point)] == .ladder;
}

pub fn canClimb(pos: Vector2, size: Vector2) bool {
    const bottomLeft = pos.addY(size.y);
    const bottomRight = pos.add(size);

    return tileStates[tileIndex(bottomLeft)] == .ladder and
        tileStates[tileIndex(bottomRight)] == .ladder;
}

pub fn clamp(old: Vector2, new: Vector2, size: Vector2) Vector2 {
    const newX = zhu.Vector2.xy(new.x, old.y);
    const clampedX = if (new.x < old.x) clampLeft(newX, size) //
        else if (new.x > old.x) clampRight(newX, size) else newX;

    const newY = zhu.Vector2.xy(old.x, new.y);
    const clampedY = if (new.y < old.y) clampUp(newY, size) //
        else if (new.y > old.y) clampDown(newY, size) else newY;

    return .xy(clampedX.x, clampedY.y);
}

const epsilon = zhu.Vector2.one.scale(-zhu.math.epsilon);
fn clampLeft(new: Vector2, size: Vector2) Vector2 {
    const sz = size.add(epsilon);

    var index = tileIndex(new);
    if (tileStates[index] == .solid) { // 左上角碰撞
        return tileWorld(index + 1);
    }

    const bottomLeft = new.addY(sz.y);
    index = tileIndex(bottomLeft);
    if (tileStates[index] == .solid) { // 左下角碰撞
        return tileWorld(index + 1);
    }
    return new;
}

fn clampRight(new: Vector2, size: Vector2) Vector2 {
    const sz = size.add(epsilon);

    var index = tileIndex(new.addX(sz.x));
    const offsetX = map.grid.cellSize().x - size.x;
    if (tileStates[index] == .solid) { // 右上角碰撞
        return tileWorld(index - 1).addX(offsetX);
    }

    const bottomRight = new.add(sz);
    index = tileIndex(bottomRight);
    if (tileStates[index] == .solid) { // 右下角碰撞
        return tileWorld(index - 1).addX(offsetX);
    }
    return new;
}

fn clampUp(new: Vector2, size: Vector2) Vector2 {
    const sz = size.add(epsilon);

    const width: usize = @intCast(map.grid.width);

    var index = tileIndex(new);
    if (tileStates[index] == .solid) { // 左上角碰撞
        return tileWorld(index + width);
    }
    index = tileIndex(new.addX(sz.x));
    if (tileStates[index] == .solid) { // 右上角碰撞
        return tileWorld(index + width);
    }
    return new;
}

fn clampDown(new: Vector2, size: Vector2) Vector2 {
    const sz = size.add(epsilon);

    const width: usize = @intCast(map.grid.width);
    var index = tileIndex(new.addY(sz.y)); // 左下角
    const offset = map.grid.cellSize().y - size.y;
    var tileEnum = tileStates[index];
    if (tileEnum == .solid or tileEnum == .uniSolid) {
        return tileWorld(index - width).addY(offset);
    }

    index = tileIndex(new.add(sz)); // 右下角
    tileEnum = tileStates[index];
    if (tileEnum == .solid or tileEnum == .uniSolid) {
        return tileWorld(index - width).addY(offset);
    }

    return new;
}

fn tileIndex(point: Vector2) usize {
    return map.grid.worldToIndex(point).?;
}

fn tileWorld(index: usize) Vector2 {
    return map.grid.indexToWorld(index);
}

pub fn draw() void {
    for (map.layers) |*layer| {
        if (layer.type == .image) drawImageLayer(layer);
    }

    batch.drawVertices(tileVertexes.items, null);
}

fn drawImageLayer(layer: *const tiled.Layer) void {
    zhu.camera.push(.window);
    defer zhu.camera.pop();

    if (layer.repeatY) {
        const image = zhu.assets.getImage(layer.image).?;
        const posY = zhu.camera.main.position.y * layer.parallaxY;
        var y = -@mod(posY, layer.height);
        while (y < window.size.y) : (y += layer.height) {
            batch.drawImage(image, layer.offset.addXY(0, y), .{});
        }
    }

    if (layer.repeatX) {
        const image = zhu.assets.getImage(layer.image).?;
        const posX = zhu.camera.main.position.x * layer.parallaxX;
        var x = -@mod(posX, layer.width);
        while (x < window.size.x) : (x += layer.width) {
            batch.drawImage(image, layer.offset.addXY(x, 0), .{});
        }
    }
}
