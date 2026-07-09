const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");

const Grid = zhu.extend.tiled.Grid;
const Position = component.Position;
const Shape = component.motion.Shape;
const Blocking = component.motion.Blocking;
const World = ecs.World;
const Entity = ecs.Entity;
const SolidRange = component.map.SolidRange;

const Spatial = @This();

// 当前地图每个瓦片上的语义标记，可组合使用。
pub const Mark = enum {
    north, // 北面阻挡
    south, // 南面阻挡
    west, // 西面阻挡
    east, // 东面阻挡
    hazard, // 危险区域
    water, // 水域
    interact, // 可交互
    arable, // 可耕作
    occupied, // 被占用
};

pub const Marks = std.EnumSet(Mark);
const solid = Marks.initMany(&.{ .north, .south, .west, .east });

grid: Grid = undefined,
tiles: []Marks = &.{},
areas: std.ArrayList(zhu.Rect) = .empty,

pub fn init(gpa: zhu.Allocator, grid: Grid) Spatial {
    var self = Spatial{ .grid = grid };
    self.tiles = gpa.alloc(Marks, self.grid.count());
    @memset(self.tiles, Marks.initEmpty());
    return self;
}

pub fn deinit(self: *Spatial, gpa: zhu.Allocator) void {
    gpa.free(self.tiles);
    self.areas.clearAndFree(gpa.raw);
}

pub fn setTileBlock(self: *Spatial, index: usize) void {
    self.tiles[index].setUnion(solid);
}

/// 根据 tile_flag 字符串设置瓦片标记
pub fn setTileFlag(self: *Spatial, index: usize, flag: []const u8) void {
    var iter = std.mem.tokenizeScalar(u8, flag, ',');
    while (iter.next()) |raw| {
        const token = std.mem.trim(u8, raw, " \t\r\n");
        if (std.mem.eql(u8, token, "SOLID")) {
            self.tiles[index].setUnion(solid);
        } else if (std.mem.eql(u8, token, "BLOCK_N")) {
            self.tiles[index].insert(.north);
        } else if (std.mem.eql(u8, token, "BLOCK_S")) {
            self.tiles[index].insert(.south);
        } else if (std.mem.eql(u8, token, "BLOCK_W")) {
            self.tiles[index].insert(.west);
        } else if (std.mem.eql(u8, token, "BLOCK_E")) {
            self.tiles[index].insert(.east);
        } else if (std.mem.eql(u8, token, "HAZARD")) {
            self.tiles[index].insert(.hazard);
        } else if (std.mem.eql(u8, token, "WATER")) {
            self.tiles[index].insert(.water);
        } else if (std.mem.eql(u8, token, "INTERACT")) {
            self.tiles[index].insert(.interact);
        } else if (std.mem.eql(u8, token, "ARABLE")) {
            self.tiles[index].insert(.arable);
        } else if (std.mem.eql(u8, token, "OCCUPIED")) {
            self.tiles[index].insert(.occupied);
        } else {
            std.debug.panic("unknown tile_flag token: {s}", .{token});
        }
    }
}

pub fn clearTileMark(self: *Spatial, index: usize, mark: Mark) void {
    self.tiles[index].remove(mark);
}

pub fn clearTileBlock(self: *Spatial, index: usize) void {
    self.tiles[index].remove(.north);
    self.tiles[index].remove(.south);
    self.tiles[index].remove(.west);
    self.tiles[index].remove(.east);
}

pub fn marksAt(self: Spatial, position: zhu.Vector2) Marks {
    const index = self.grid.worldToIndex(position);
    return self.tiles[index orelse return .initEmpty()];
}

pub fn hasAnyBlock(marks: Marks) bool {
    return marks.contains(.north) or marks.contains(.south) or
        marks.contains(.west) or marks.contains(.east);
}

pub fn canHoeTile(self: Spatial, position: zhu.Vector2) bool {
    const marks = self.marksAt(position);
    if (!marks.contains(.arable)) return false;
    if (marks.contains(.water)) return false;
    if (marks.contains(.occupied)) return false;
    if (hasAnyBlock(marks)) return false;
    return true;
}

pub fn addSolidRect(self: *Spatial, gpa: zhu.Allocator, rect: zhu.Rect) void {
    std.debug.assert(rect.size.x > 0 and rect.size.y > 0);
    self.areas.append(gpa.raw, rect) catch zhu.oom();
}

// SolidRange 只记录对象加入 areas 时的起点和数量。
pub fn solidAreas(self: Spatial, range: SolidRange) []zhu.Rect {
    return self.areas.items[range.start..][0..range.count];
}

pub fn clearSolidRange(self: *Spatial, range: SolidRange) void {
    for (self.solidAreas(range)) |*area| area.* = .init(.zero, .zero);
}

/// 检查碰撞体放在指定位置后是否被阻挡
pub fn isBlocked(self: Spatial, position: zhu.Vector2, collider: Shape) bool {
    // 将碰撞体偏移到绝对位置
    const shape = collider.move(position);
    const bounds = shape.toRect();
    const mapBounds = zhu.Rect.init(.zero, self.grid.size());
    if (!mapBounds.contains(bounds)) return true;

    var iter = self.grid.cellsInRect(bounds);
    while (iter.next()) |index| {
        const marks = self.tiles[index];
        const tileRect = self.grid.indexToRect(index);
        if (marks.supersetOf(solid)) {
            // 精确检测：圆形用圆-矩形相交，矩形用矩形相交
            if (shape.intersect(tileRect)) return true;
            continue;
        }

        // 方向标记表示半格阻挡，目标碰撞体进入半格区域就被挡住。
        const size = tileRect.size.x;
        const half = size * 0.5;
        const pos = tileRect.min;
        if (marks.contains(.north)) {
            const rect = zhu.Rect.init(pos, .xy(size, half));
            if (shape.intersect(rect)) return true;
        }
        if (marks.contains(.south)) {
            const rect = zhu.Rect.init(pos.addY(half), .xy(size, half));
            if (shape.intersect(rect)) return true;
        }
        if (marks.contains(.west)) {
            const rect = zhu.Rect.init(pos, .xy(half, size));
            if (shape.intersect(rect)) return true;
        }
        if (marks.contains(.east)) {
            const rect = zhu.Rect.init(pos.addX(half), .xy(half, size));
            if (shape.intersect(rect)) return true;
        }
    }

    // 精确碰撞检测：用 Shape.intersect 与区域矩形相交
    for (self.areas.items) |area| {
        if (shape.intersect(area)) return true;
    }
    return false;
}

/// 检查实体能否从当前位置移动到目标位置。
pub fn canMove(self: Spatial, world: *World, entity: Entity, to: zhu.Vector2) bool {
    const body = world.get(entity, Shape).?;
    if (self.isBlocked(to, body)) return false;

    const moved = body.move(to);
    var query = world.query(.{ Position, Shape, Blocking });
    while (query.next()) |other| {
        if (other == entity) continue;

        const otherPosition = query.get(other, Position);
        const otherBody = query.get(other, Shape);
        const otherShape = otherBody.move(otherPosition);
        if (moved.intersect(otherShape)) return false;
    }

    return true;
}

test "isBlocked 检测碰撞框是否与 solid 格子重叠" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const collider: Shape = .{
        .rect = .init(.xy(-5, -6), .xy(10, 6)),
    };
    // 空地图不应碰撞
    try std.testing.expect(!spatial.isBlocked(.xy(24, 40), collider));

    // 标记 tile (1,2) 为 solid
    spatial.tiles[spatial.grid.worldToIndex(.xy(24, 40)).?].setUnion(solid);
    try std.testing.expect(spatial.isBlocked(.xy(24, 40), collider));
    try std.testing.expect(!spatial.isBlocked(.xy(80, 80), collider));
}

test "isBlocked 方向标记会阻挡对应半格" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const collider: Shape = .{
        .rect = .init(.zero, .xy(10, 6)),
    };
    const index = spatial.grid.worldToIndex(.xy(40, 40)).?;
    spatial.tiles[index].insert(.north); // 上半格阻挡

    try std.testing.expect(!spatial.isBlocked(.xy(36, 26), collider));
    try std.testing.expect(spatial.isBlocked(.xy(36, 27), collider));
    try std.testing.expect(!spatial.isBlocked(.xy(36, 41), collider));
}

test "isBlocked 支持南侧半格阻挡" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const collider: Shape = .{
        .rect = .init(.zero, .xy(8, 8)),
    };
    const index = spatial.grid.worldToIndex(.xy(40, 24)).?;
    spatial.tiles[index].insert(.south);

    try std.testing.expect(!spatial.isBlocked(.xy(36, 15), collider));
    try std.testing.expect(spatial.isBlocked(.xy(36, 17), collider));
}

test "isBlocked 支持东侧半格阻挡" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const collider: Shape = .{
        .rect = .init(.zero, .xy(8, 8)),
    };
    const index = spatial.grid.worldToIndex(.xy(24, 40)).?;
    spatial.tiles[index].insert(.east);

    try std.testing.expect(!spatial.isBlocked(.xy(15, 36), collider));
    try std.testing.expect(spatial.isBlocked(.xy(17, 36), collider));
}

test "isBlocked 不会把贴边当成碰撞" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    spatial.tiles[spatial.grid.worldToIndex(.xy(40, 40)).?].setUnion(solid);
    const collider: Shape = .{
        .rect = .init(.zero, .xy(10, 6)),
    };

    try std.testing.expect(!spatial.isBlocked(.xy(22, 36), collider));
    try std.testing.expect(!spatial.isBlocked(.xy(36, 26), collider));
    try std.testing.expect(spatial.isBlocked(.xy(23, 36), collider));
}

test "isBlocked 允许碰撞体贴住地图最大边界" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const collider: Shape = .{
        .rect = .init(.zero, .xy(10, 10)),
    };
    const size = spatial.grid.size();
    const position = size.sub(.xy(10, 10));

    try std.testing.expect(!spatial.isBlocked(position, collider));
}

test "isBlocked 阻挡碰撞体越过地图边界" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const collider: Shape = .{
        .rect = .init(.zero, .xy(10, 10)),
    };
    const size = spatial.grid.size();

    try std.testing.expect(spatial.isBlocked(.xy(-0.1, 0), collider));
    try std.testing.expect(spatial.isBlocked(
        .xy(size.x - 9.9, 0),
        collider,
    ));
    try std.testing.expect(spatial.isBlocked(.xy(0, -0.1), collider));
    try std.testing.expect(spatial.isBlocked(
        .xy(0, size.y - 9.9),
        collider,
    ));
}

test "对象 collider 使用精确矩形保留桌子间通道" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    spatial.addSolidRect(zhu.testing.allocator, .init(
        .xy(83.083336, 106.208336),
        .xy(26.5, 28.25),
    ));
    spatial.addSolidRect(zhu.testing.allocator, .init(
        .xy(83.04163, 154.22884),
        .xy(26.5, 28.25),
    ));

    const collider: Shape = .{
        .rect = .init(.xy(-5, -6), .xy(10, 6)),
    };

    try std.testing.expect(!spatial.isBlocked(.xy(96, 144), collider));
    try std.testing.expect(spatial.isBlocked(.xy(96, 120), collider));
}

test "setTileFlag 支持地图语义标记" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const position = zhu.Vector2.xy(24, 40);
    const index = spatial.grid.worldToIndex(position).?;

    spatial.setTileFlag(index, "ARABLE,OCCUPIED,WATER,HAZARD,INTERACT");

    const marks = spatial.marksAt(position);
    try std.testing.expect(marks.contains(.arable));
    try std.testing.expect(marks.contains(.occupied));
    try std.testing.expect(marks.contains(.water));
    try std.testing.expect(marks.contains(.hazard));
    try std.testing.expect(marks.contains(.interact));
}

test "setTileFlag 支持 SOLID 与其它标记组合" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const position = zhu.Vector2.xy(24, 40);
    const index = spatial.grid.worldToIndex(position).?;

    spatial.setTileFlag(index, "SOLID,ARABLE");

    const marks = spatial.marksAt(position);
    try std.testing.expect(hasAnyBlock(marks));
    try std.testing.expect(marks.contains(.arable));
}

test "canHoeTile 要求可耕作且没有地图阻挡语义" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const position = zhu.Vector2.xy(24, 40);
    const index = spatial.grid.worldToIndex(position).?;

    try std.testing.expect(!spatial.canHoeTile(position));

    spatial.tiles[index].insert(.arable);
    try std.testing.expect(spatial.canHoeTile(position));

    spatial.tiles[index].insert(.water);
    try std.testing.expect(!spatial.canHoeTile(position));
    spatial.tiles[index].remove(.water);

    spatial.tiles[index].insert(.occupied);
    try std.testing.expect(!spatial.canHoeTile(position));
    spatial.tiles[index].remove(.occupied);

    spatial.tiles[index].insert(.north);
    try std.testing.expect(!spatial.canHoeTile(position));
}

test "isBlocked 圆形碰撞体检测 solid 瓦片" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    const collider: Shape = .{
        .circle = .init(.xy(0, -5), 5),
    };

    // 空地图不碰撞
    try std.testing.expect(
        !spatial.isBlocked(.xy(24, 40), collider),
    );

    // solid 格子碰撞
    spatial.tiles[spatial.grid.worldToIndex(.xy(24, 40)).?].setUnion(solid);
    try std.testing.expect(
        spatial.isBlocked(.xy(24, 40), collider),
    );
}

test "isBlocked 圆形碰撞体与区域矩形精确碰撞" {
    const grid = Grid{ .width = 10, .height = 12, .cell = 16 };
    var spatial = Spatial.init(zhu.testing.allocator, grid);
    defer spatial.deinit(zhu.testing.allocator);

    spatial.addSolidRect(zhu.testing.allocator, .init(.xy(83, 106), .xy(26, 28)));

    const collider: Shape = .{
        .circle = .init(.xy(0, -5), 5),
    };

    // 圆心远离矩形，不碰撞
    try std.testing.expect(!spatial.isBlocked(.xy(60, 100), collider));
    // 圆心靠近矩形左边缘，碰撞（圆心距矩形 2px，半径 5px）
    try std.testing.expect(spatial.isBlocked(.xy(78, 120), collider));
}
