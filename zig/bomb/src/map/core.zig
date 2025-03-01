const std = @import("std");
const engine = @import("../engine.zig");

var tilemap: engine.Tilemap = undefined;

pub fn init() void {
    tilemap = engine.Tilemap.init("map.png", 32);
}

pub fn deinit() void {
    tilemap.deinit();
}

pub const Direction = enum { north, south, west, east };

pub const MapType = enum(u8) {
    space = 9,
    wall = 7,
    brick = 8,
    item = 2,
    power = 3,
    bomb = 10,
    fireX = 4,
    fireY = 5,
    explosion = 11,
    player1 = 1,
    player2 = 0,
    enemy = 6,
};

pub const StageConfig = struct {
    enemy: usize,
    brickRate: usize,
    power: usize,
    bomb: usize,
};

const width = 19;
const height = 15;
var data: [width * height]MapUnit = undefined;

pub fn getWidth() usize {
    return width;
}

pub fn getHeight() usize {
    return height;
}

pub fn getSize() usize {
    return getWidth() * getHeight();
}

pub fn getMapData() []MapUnit {
    return &data;
}

pub fn getMapUnit() usize {
    return tilemap.unit;
}

pub fn isFixWall(x: usize, y: usize) bool {
    if (x == 0 or y == 0) return true;
    if (x == width - 1 or y == height - 1) return true;
    if (x % 2 == 0 and y % 2 == 0) return true;
    return false;
}

pub fn isFixSpace(x: usize, y: usize, twoPlayer: bool) bool {
    if (x + y < 4) return true;
    if (twoPlayer and x + y > width + height - 6) return true;
    return false;
}

fn drawTile(mapType: MapType, x: usize, y: usize) void {
    tilemap.drawTile(@intFromEnum(mapType), x, y);
}

pub fn drawXY(mapType: MapType, x: usize, y: usize) void {
    tilemap.drawXY(@intFromEnum(mapType), x, y);
}

const MapTypes = std.enums.EnumSet(MapType);
pub const MapUnit = struct {
    mapTypes: MapTypes,
    time: usize = std.math.maxInt(usize),

    pub fn init(mapType: MapType) MapUnit {
        return .{ .mapTypes = MapTypes.initOne(mapType) };
    }

    pub fn contains(self: MapUnit, mapType: MapType) bool {
        return self.mapTypes.contains(mapType);
    }

    pub fn hasExplosion(self: MapUnit) bool {
        return self.contains(.explosion) //
        or self.contains(.fireX) or self.contains(.fireY);
    }

    pub fn remove(self: *MapUnit, mapType: MapType) void {
        self.mapTypes.remove(mapType);
    }

    pub fn insert(self: *MapUnit, mapType: MapType) void {
        self.mapTypes.insert(mapType);
    }

    pub fn insertTimedType(self: *MapUnit, mapType: MapType, time: usize) void {
        self.insert(mapType);
        self.time = time;
    }

    pub fn draw(self: MapUnit, x: usize, y: usize) void {
        if (self.contains(.wall)) return drawTile(.wall, x, y);
        if (self.contains(.brick)) return drawTile(.brick, x, y);

        drawTile(.space, x, y);
        if (self.contains(.power)) drawTile(.power, x, y);
        if (self.contains(.item)) drawTile(.item, x, y);
        if (self.contains(.bomb)) drawTile(.bomb, x, y);
        if (self.contains(.explosion)) drawTile(.explosion, x, y);
        if (self.contains(.fireX)) drawTile(.fireX, x, y);
        if (self.contains(.fireY)) drawTile(.fireY, x, y);
    }
};
