const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const tiled = zhu.extend.tiled;

const Land = @This();

grid: tiled.Grid = undefined,
tiles: []Tile = &.{},

const Object = struct {
    const Kind = enum { crop, product, chest };
    kind: Kind,
    entity: ecs.Entity,
};

pub const Tile = struct {
    ground: ?component.farm.Ground = null,
    object: ?Object = null,
    gone: enum { none, product } = .none,

    pub fn get(self: Tile, kind: Object.Kind) ?ecs.Entity {
        const object = self.object orelse return null;
        if (object.kind != kind) return null;
        return object.entity;
    }

    pub fn set(self: *Tile, kind: Object.Kind, e: ecs.Entity) void {
        self.object = .{ .kind = kind, .entity = e };
    }
};

pub fn init(gpa: zhu.Allocator, grid: tiled.Grid) Land {
    var self = Land{ .grid = grid };
    self.tiles = gpa.alloc(Tile, grid.count());
    @memset(self.tiles, .{});
    return self;
}

pub fn deinit(self: *Land, gpa: zhu.Allocator) void {
    gpa.free(self.tiles);
}

pub fn getTile(self: Land, pos: zhu.Vector2) ?*Tile {
    const index = self.grid.worldToIndex(pos) orelse return null;
    return &self.tiles[index];
}

pub fn canHoe(self: Land, position: zhu.Vector2) bool {
    const tile = self.getTile(position) orelse return false;
    if (tile.ground != null) return false;
    if (tile.object != null) return false;
    return true;
}

pub fn canPlant(self: Land, position: zhu.Vector2) bool {
    const tile = self.getTile(position) orelse return false;
    if (tile.ground == null) return false;
    if (tile.object != null) return false;
    return true;
}

pub fn hoe(self: *Land, position: zhu.Vector2) bool {
    if (!self.canHoe(position)) return false;
    const tile = self.getTile(position).?;
    tile.ground = .dry;
    return true;
}

pub fn water(self: *Land, position: zhu.Vector2) bool {
    const tile = self.getTile(position) orelse return false;
    if (tile.ground == null) return false;
    tile.ground = .wet;
    return true;
}

pub fn draw(self: Land, dry: zhu.Image, wet: zhu.Image) void {
    for (self.tiles, 0..) |tile, index| {
        const ground = tile.ground orelse continue;
        const position = self.grid.indexToWorld(index);
        appendVertex(position, dry);
        if (ground == .wet) appendVertex(position, wet);
    }
}

fn appendVertex(position: zhu.Vector2, image: zhu.Image) void {
    zhu.batch.vertices.appendAssumeCapacity(.{
        .position = position,
        .layer = image.layer,
        .size = image.size,
        .uvRect = image.uvRect(),
    });
}

test "锄地会记录目标格" {
    const grid = tiled.Grid{ .width = 3, .height = 4, .cell = 16 };
    var land = Land.init(zhu.testing.allocator, grid);
    defer land.deinit(zhu.testing.allocator);

    try std.testing.expect(land.hoe(.xy(32, 48)));

    try std.testing.expectEqual(.dry, land.getTile(.xy(32, 48)).?.ground);
}

test "浇水只会影响已有耕地" {
    const grid = tiled.Grid{ .width = 3, .height = 4, .cell = 16 };
    var land = Land.init(zhu.testing.allocator, grid);
    defer land.deinit(zhu.testing.allocator);

    try std.testing.expect(!land.water(.xy(32, 48)));
    try std.testing.expectEqual(null, land.getTile(.xy(32, 48)).?.ground);

    try std.testing.expect(land.hoe(.xy(32, 48)));
    try std.testing.expect(land.water(.xy(32, 48)));
    try std.testing.expectEqual(.wet, land.getTile(.xy(32, 48)).?.ground);
}

test "目标格有作物时不会锄地" {
    const grid = tiled.Grid{ .width = 3, .height = 4, .cell = 16 };
    var land = Land.init(zhu.testing.allocator, grid);
    defer land.deinit(zhu.testing.allocator);

    land.getTile(.xy(32, 48)).?.set(.crop, 1);

    try std.testing.expect(!land.hoe(.xy(32, 48)));
    try std.testing.expectEqual(null, land.getTile(.xy(32, 48)).?.ground);
}

test "锄地要求地块为空" {
    const grid = tiled.Grid{ .width = 3, .height = 4, .cell = 16 };
    var land = Land.init(zhu.testing.allocator, grid);
    defer land.deinit(zhu.testing.allocator);

    const position = zhu.Vector2.xy(32, 48);

    try std.testing.expect(land.canHoe(position));

    land.getTile(position).?.ground = .dry;
    try std.testing.expect(!land.canHoe(position));

    land.getTile(position).?.ground = null;
    land.getTile(position).?.set(.crop, 1);
    try std.testing.expect(!land.canHoe(position));
}

test "种植只要求已有耕地且没有对象" {
    const grid = tiled.Grid{ .width = 3, .height = 4, .cell = 16 };
    var land = Land.init(zhu.testing.allocator, grid);
    defer land.deinit(zhu.testing.allocator);

    const position = zhu.Vector2.xy(32, 48);
    const tile = land.getTile(position).?;

    try std.testing.expect(!land.canPlant(position));

    tile.ground = .dry;
    try std.testing.expect(land.canPlant(position));

    tile.set(.crop, 1);
    try std.testing.expect(!land.canPlant(position));
}

test "浇水要求已有耕地" {
    const grid = tiled.Grid{ .width = 3, .height = 4, .cell = 16 };
    var land = Land.init(zhu.testing.allocator, grid);
    defer land.deinit(zhu.testing.allocator);

    const position = zhu.Vector2.xy(32, 48);
    const tile = land.getTile(position).?;

    try std.testing.expect(!land.water(position));

    tile.ground = .dry;
    try std.testing.expect(land.water(position));
    try std.testing.expectEqual(.wet, tile.ground.?);

    tile.set(.crop, 1);
    try std.testing.expect(land.water(position));
}
