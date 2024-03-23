const std = @import("std");
const engine = @import("../engine.zig");
const core = @import("core.zig");
const Player = @import("player.zig").Player;

fn genMap(world: *World, twoPlayer: bool, config: core.StageConfig) void {
    var bricks: [core.getSize()]usize = undefined;
    var brickNumber: usize = 0;
    var floors: [core.getSize()]usize = undefined;
    var floorNumber: usize = 0;

    for (0..world.height) |y| {
        for (0..world.width) |x| {
            world.data[x + y * world.width] = if (core.isFixWall(x, y))
                core.MapUnit.init(.wall)
            else if (core.isFixSpace(x, y, twoPlayer))
                core.MapUnit.init(.space)
            else if (engine.random(100) < config.brickRate) label: {
                bricks[brickNumber] = x << 16 | y;
                brickNumber += 1;
                break :label core.MapUnit.init(.brick);
            } else label: {
                floors[floorNumber] = x << 16 | y;
                floorNumber += 1;
                break :label core.MapUnit.init(.space);
            };
        }
    }
    genItem(world, bricks[0..brickNumber], config);
    genEnemy(world, twoPlayer, floors[0..floorNumber], config.enemy);
}

fn genItem(self: *World, bricks: []usize, cfg: core.StageConfig) void {
    for (0..cfg.bomb + cfg.power) |i| {
        const swapped = engine.randomW(i, bricks.len);
        const tmp = bricks[i];
        bricks[i] = bricks[swapped];
        bricks[swapped] = tmp;
        const x = bricks[i] >> 16 & 0xFFFF;
        const item: core.MapType = if (i < cfg.power) .power else .item;
        self.data[x + (bricks[i] & 0xFFFF) * self.width].insert(item);
    }
}

fn genEnemy(world: *World, two: bool, floors: []usize, enemy: usize) void {
    const index: usize = if (two) 2 else 1;
    for (0..enemy) |i| {
        const swapped = engine.randomW(i, floors.len);
        const tmp = floors[i];
        floors[i] = floors[swapped];
        floors[swapped] = tmp;
        const x = floors[i] >> 16 & 0xFFFF;
        world.players[index + i] = Player.genEnemy(x, floors[i] & 0xFFFF);
    }
}

const bombDelayTime = 3000;

pub const World = struct {
    width: usize = core.getWidth(),
    height: usize = core.getHeight(),
    unit: usize,
    data: []core.MapUnit = core.getMapData(),
    players: []Player,
    running: bool = true,

    pub fn init(twoPlayer: bool, config: core.StageConfig) ?World {
        const number = config.enemy + @as(usize, if (twoPlayer) 2 else 1);
        const players = engine.allocator.alloc(Player, number) catch |e| {
            std.log.info("create players error: {}", .{e});
            return null;
        };

        var map = World{ .unit = core.getMapUnit(), .players = players };
        genMap(&map, twoPlayer, config);
        return map;
    }

    pub fn update(self: *World) void {
        const time = engine.time();
        for (self.data, 0..) |*value, idx| {
            if (value.contains(.bomb)) {
                if (time > value.time + bombDelayTime) {
                    var p = if (value.contains(.player1))
                        self.player1()
                    else
                        self.player2();
                    self.explosion(value, p.*, idx);
                    p.bombNumber -|= 1;
                    value.remove(p.type);
                }
            }
            if (value.contains(.explosion)) {
                if (time > value.time + 700) {
                    value.remove(.explosion);
                }
            }

            if (value.contains(.fireX)) {
                if (time > value.time + 700) {
                    value.remove(.fireX);
                }
            }

            if (value.contains(.fireY)) {
                if (time > value.time + 700) {
                    value.remove(.fireY);
                }
            }
        }
    }

    fn explosion(self: *World, mapUnit: *core.MapUnit, player: Player, idx: usize) void {
        const time = engine.time();
        mapUnit.remove(.bomb);
        mapUnit.insertTimedType(.explosion, time);
        // 左
        self.explosionLeft(time, player, idx);
        // 右
        self.explosionRight(time, player, idx);
        // 上
        self.explosionUp(time, player, idx);
        // 下
        self.explosionDown(time, player, idx);
    }

    fn explosionLeft(self: *World, time: usize, player: Player, idx: usize) void {
        for (1..player.maxBombLength + 1) |i| {
            const mapUnit = &self.data[idx -| i];
            if (explosionMap(mapUnit) orelse return) continue;
            mapUnit.insertTimedType(.fireX, time);
        }
    }

    fn explosionMap(mapUnit: *core.MapUnit) ?bool {
        if (mapUnit.contains(.wall)) return null;
        if (mapUnit.contains(.brick)) {
            mapUnit.remove(.brick);
            return null;
        }
        if (mapUnit.contains(.bomb)) {
            mapUnit.time -|= bombDelayTime;
            return true;
        }
        return false;
    }

    fn explosionRight(self: *World, time: usize, player: Player, idx: usize) void {
        for (1..player.maxBombLength + 1) |i| {
            const mapUnit = &self.data[idx + i];
            if (explosionMap(mapUnit) orelse return) continue;
            mapUnit.insertTimedType(.fireX, time);
        }
    }

    fn explosionUp(self: *World, time: usize, player: Player, idx: usize) void {
        for (1..player.maxBombLength + 1) |i| {
            const mapUnit = &self.data[idx -| (self.width * i)];
            if (explosionMap(mapUnit) orelse return) continue;
            mapUnit.insertTimedType(.fireY, time);
        }
    }

    fn explosionDown(self: *World, time: usize, player: Player, idx: usize) void {
        for (1..player.maxBombLength + 1) |i| {
            const mapUnit = &self.data[idx + (self.width * i)];
            if (explosionMap(mapUnit) orelse return) continue;
            mapUnit.insertTimedType(.fireY, time);
        }
    }

    pub fn isCollisionX(self: World, player: Player, x: usize, y: usize) bool {
        const rect = player.toCollisionRec();
        for (0..3) |i| {
            if (self.isCollision(x, y + i -| 1, rect)) return true;
        } else return false;
    }

    pub fn isCollisionY(self: World, player: Player, x: usize, y: usize) bool {
        const rect = player.toCollisionRec();
        for (0..3) |i| {
            if (self.isCollision(x + i -| 1, y, rect)) return true;
        } else return false;
    }

    pub fn isCollision(self: World, x: usize, y: usize, rect: engine.Rectangle) bool {
        const cell = self.index(x, y);
        if (!cell.contains(.wall) and !cell.contains(.brick) //
        and !cell.contains(.bomb)) return false;

        const rec = engine.Rectangle{ .x = x, .y = y, .width = 1, .height = 1 };
        return engine.isCollision(rec.scale(self.unit), rect);
    }

    pub fn draw(self: World) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                self.data[x + y * self.width].draw(x, y);
            }
        }

        for (self.players) |value| if (value.alive) value.draw();
    }

    pub fn player1(self: World) *Player {
        return &self.players[0];
    }

    pub fn player2(self: World) *Player {
        return &self.players[1];
    }

    pub fn index(self: World, x: usize, y: usize) core.MapUnit {
        return self.data[x + y * self.width];
    }

    pub fn indexRef(self: *World, x: usize, y: usize) *core.MapUnit {
        return &self.data[x + y * self.width];
    }

    pub fn size(self: World) usize {
        return self.width * self.height;
    }

    pub fn deinit(self: World) void {
        engine.allocator.free(self.players);
    }
};
