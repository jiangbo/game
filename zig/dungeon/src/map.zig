const std = @import("std");
const zhu = @import("zhu");

const ecs = @import("ecs");
const game = @import("world.zig");

const component = @import("component.zig");
const builder = @import("builder.zig");

const Position = component.Position;
const TilePosition = component.TilePosition;
const TileRect = component.TileRect;
const WantToMove = component.WantToMove;
const Player = component.Player;
const Tile = component.Tile;
const ViewField = component.ViewField;

const Theme = enum { dungeon, forest };

const WIDTH = builder.WIDTH;
const HEIGHT = builder.HEIGHT;
pub const TILE_SIZE: zhu.Vector2 = .xy(32, 32);
pub const MAX_LEVEL = 3;
const TILE_PER_ROW = 16;

pub var size = zhu.Vector2.xy(WIDTH, HEIGHT).mul(TILE_SIZE);
pub var spawns: [builder.SPAWN_SIZE]TilePosition = undefined;
pub var finalPos: TilePosition = undefined;
pub var currentLevel: u8 = 1;

var tiles: [WIDTH * HEIGHT]Tile = undefined;
var image: zhu.Image = undefined;
var walks: [HEIGHT * WIDTH]bool = undefined;
var theme: Theme = undefined;

pub fn init(mapLevel: u8) void {
    image = zhu.assets.loadImage("dungeonfont.png", .xy(512, 512));
    theme = if (zhu.random.boolean()) .dungeon else .forest;
    currentLevel = mapLevel;

    switch (zhu.random.int(u8, 0, 3)) {
        1 => builder.buildRooms(&tiles, &spawns),
        2 => builder.buildAutometa(&tiles, &spawns),
        else => builder.buildDrunkard(&tiles, &spawns),
    }

    @memset(&walks, false);
    updateDistance(spawns[0]);

    var max: u8 = 0;
    for (&distances, 0..) |*line, y| {
        for (line, 0..) |value, x| {
            if (value == 0xFF or value <= max) continue;
            max = value;
            finalPos = .{ .x = @intCast(x), .y = @intCast(y) };
        }
    }

    applyPrefab();
}

const FORTRESS: [11][12]u8 = .{
    .{ 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46 },
    .{ 46, 46, 46, 35, 35, 35, 35, 35, 35, 46, 46, 46 },
    .{ 46, 46, 46, 35, 46, 46, 46, 46, 35, 46, 46, 46 },
    .{ 46, 46, 46, 35, 46, 79, 46, 46, 35, 46, 46, 46 },
    .{ 46, 35, 35, 35, 46, 46, 46, 46, 35, 35, 35, 46 },
    .{ 46, 46, 79, 46, 46, 46, 46, 46, 46, 79, 46, 46 },
    .{ 46, 35, 35, 35, 46, 46, 46, 46, 35, 35, 35, 46 },
    .{ 46, 46, 46, 35, 46, 46, 46, 46, 35, 46, 46, 46 },
    .{ 46, 46, 46, 35, 46, 46, 46, 46, 35, 46, 46, 46 },
    .{ 46, 46, 46, 35, 35, 35, 35, 35, 35, 46, 46, 46 },
    .{ 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46, 46 },
};

fn applyPrefab() void {
    var rect: ?TileRect = null;

    blk: for (0..10) |_| {
        const prefab = TileRect{
            .x = zhu.random.int(u8, 0, WIDTH - FORTRESS[0].len),
            .y = zhu.random.int(u8, 0, HEIGHT - FORTRESS.len),
            .w = FORTRESS[0].len,
            .h = FORTRESS.len,
        };

        if (prefab.contains(finalPos)) continue;
        for (prefab.y..prefab.y + prefab.h) |y| {
            for (prefab.x..prefab.x + prefab.w) |x| {
                const distance = distances[y][x];
                if (distance != 0xFF and distance > 20) {
                    rect = prefab;
                    break :blk;
                }
            }
        }
    }
    if (rect == null) return; // 没有找到放置的地方

    var prefabSpawnsArray: [3]usize = .{ 0, 0, 0 };
    var count: usize = 0;
    for (spawns[1..], 1..) |pos, index| {
        if (rect.?.contains(pos)) {
            prefabSpawnsArray[count] = index;
            count += 1;
        }
        if (count == prefabSpawnsArray.len) break;
    }

    const prefabSpawns = prefabSpawnsArray[0..count];
    count = 0;

    const start = TilePosition{ .x = rect.?.x, .y = rect.?.y };
    for (0..FORTRESS.len) |y| {
        for (0..FORTRESS[0].len) |x| {
            const index = indexUsize(start.x + x, start.y + y);
            if (FORTRESS[y][x] == 79) {
                const i = if (count < prefabSpawns.len)
                    prefabSpawns[count]
                else
                    zhu.random.int(u8, 1, spawns.len);
                const dx: u8 = @intCast(start.x + x);
                spawns[i] = .{ .x = dx, .y = @intCast(start.y + y) };
                count += 1;
                tiles[index] = .floor;
            } else tiles[index] = @enumFromInt(FORTRESS[y][x]);
        }
    }
}

pub fn getTextureFromTile(tile: Tile) zhu.Image {
    var index: usize = @intFromEnum(tile);
    if (theme == .forest) {
        if (tile == .wall) index = 34;
        if (tile == .floor) index = 59;
    }

    const row: f32 = @floatFromInt(index / TILE_PER_ROW);
    const col: f32 = @floatFromInt(index % TILE_PER_ROW);
    const pos = zhu.Vector2.xy(col, row).mul(TILE_SIZE);
    return image.sub(.init(pos, TILE_SIZE));
}

fn getPositionFromIndex(index: usize) zhu.Vector2 {
    const row: f32 = @floatFromInt(index / WIDTH);
    const col: f32 = @floatFromInt(index % WIDTH);
    return zhu.Vector2.xy(col, row).mul(TILE_SIZE);
}

const indexUsize = builder.indexUsize;
pub fn indexTile(x: usize, y: usize) Tile {
    return tiles[indexUsize(x, y)];
}

pub fn worldPosition(pos: TilePosition) Position {
    return pos.toVector().mul(TILE_SIZE);
}

pub fn canMove(pos: TilePosition) bool {
    return pos.x < WIDTH and pos.y < HEIGHT //
    and indexTile(pos.x, pos.y) != .wall;
}

pub fn moveIfNeed() void {
    var query = game.world.query(.{ WantToMove, TilePosition, Position });
    blk: while (query.next()) |entity| {
        const dest = query.get(entity, WantToMove)[0];
        if (!canMove(dest)) continue;

        for (game.world.values(TilePosition)) |pos| {
            if (pos.equals(dest)) continue :blk;
        }

        query.getPtr(entity, TilePosition).* = dest;
        const pos = worldPosition(dest);
        query.getPtr(entity, Position).* = pos;
    }
}

var distances: [HEIGHT][WIDTH]u8 = undefined;
const directions: [4]TilePosition = .{
    .{ .x = 1, .y = 0 }, .{ .x = 0xFF, .y = 0 },
    .{ .x = 0, .y = 1 }, .{ .x = 0, .y = 0xFF },
};
pub fn updateDistance(pos: TilePosition) void {
    for (&distances) |*row| @memset(row, 0xFF);

    var queue: std.ArrayList(TilePosition) = .empty;
    defer queue.deinit(game.world.allocator);

    distances[pos.y][pos.x] = 0;
    queue.append(game.world.allocator, pos) catch zhu.oom();

    var read: usize = 0;
    while (read < queue.items.len) : (read += 1) {
        const min = queue.items[read];
        const distance = distances[min.y][min.x];

        for (directions) |dir| {
            const x, const y = .{ min.x +% dir.x, min.y +% dir.y };
            if (x >= WIDTH or y >= HEIGHT) continue; // 超过地图
            if (tiles[indexUsize(x, y)] != .floor) continue; // 不可通过

            if (distance + 1 < distances[y][x]) {
                distances[y][x] = distance + 1;
                queue.append(game.world.allocator, .{
                    .x = x,
                    .y = y,
                }) catch zhu.oom();
            }
        }
    }
}

pub fn queryLessDistance(pos: TilePosition) ?TilePosition {
    const distance = distances[pos.y][pos.x];
    if (distance == 0) return null;

    var r1: ?TilePosition, var r2: ?TilePosition = .{ null, null };
    for (directions) |dir| {
        const x, const y = .{ pos.x +% dir.x, pos.y +% dir.y };
        if (x >= WIDTH or y >= HEIGHT) continue; // 超过地图

        if (distances[y][x] < distance) {
            const r = TilePosition{ .x = x, .y = y };
            if (distance > 4) return r; // 远距离直接返回
            if (r1 == null) r1 = r else r2 = r;
        }
    }
    if (r2 == null) return r1;
    return if (zhu.random.boolean()) r1 else r2;
}

pub fn updatePlayerWalk() void {
    const player = game.world.getIdentity(Player).?;
    const viewField = game.world.get(player, ViewField).?[0];

    for (viewField.y..viewField.y + viewField.h) |y| {
        for (viewField.x..viewField.x + viewField.w) |x| {
            walks[indexUsize(x, y)] = true;
        }
    }
}

pub var minMap: bool = false;
pub fn draw() void {
    // for (&tiles, 0..) |tile, index| {
    //     const tex = getTextureFromTile(tile);
    //     zhu.camera.draw(tex, getPositionFromIndex(index));
    // }
    drawPlayerWalk();
    drawPlayerView();
}

fn drawPlayerWalk() void {
    const playerEntity = game.world.getIdentity(Player).?;
    const viewField = game.world.get(playerEntity, ViewField).?[0];

    for (walks, 0..) |isWalk, index| {
        if (!isWalk) continue;
        const pos = TilePosition{
            .x = @intCast(index % WIDTH),
            .y = @intCast(index / WIDTH),
        };
        if (viewField.contains(pos)) continue;

        const tex = getTextureFromTile(tiles[index]);
        zhu.batch.drawImage(tex, getPositionFromIndex(index), .{
            .color = .rgba(0.5, 0.5, 0.5, 1),
        });
    }
}

fn drawPlayerView() void {
    const player = game.world.getIdentity(Player).?;
    const viewField = game.world.get(player, ViewField).?[0];

    for (viewField.x..viewField.x + viewField.w) |x| {
        for (viewField.y..viewField.y + viewField.h) |y| {
            const index = indexUsize(x, y);
            const tex = getTextureFromTile(tiles[index]);
            zhu.batch.drawImage(tex, getPositionFromIndex(index), .{});
        }
    }
}
