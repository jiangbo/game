const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

pub const Position = zhu.gfx.Vector;
pub const Texture = zhu.gfx.Texture;
pub const TurnState = enum { player, monster, over, win, next };
pub const Health = struct { current: i32, max: i32 };
pub const Name = struct { []const u8 };
pub const Player = struct {};
pub const Enemy = struct {};
pub const ChasePlayer = struct {};
pub const Amulet = struct {};

pub const Tile = enum(u8) {
    other = 0,
    heal = 33,
    wall = 35,
    floor = 46,
    hugeSword = 47,
    exit = 62,
    player = 64,
    ettin = 69,
    ogre = 79,
    shinySword = 83,
    goblin = 103,
    orc = 111,
    zigSword = 115,
    map = 123,
    amulet = 124,
};

pub const TilePosition = struct {
    x: u8,
    y: u8,
    pub fn equals(self: TilePosition, other: TilePosition) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn toVector(self: TilePosition) Position {
        return .{ .x = @floatFromInt(self.x), .y = @floatFromInt(self.y) };
    }

    pub fn distanceSquared(self: TilePosition, other: TilePosition) usize {
        const dx = @as(i32, self.x) - @as(i32, other.x);
        const dy = @as(i32, self.y) - @as(i32, other.y);
        return @intCast(dx * dx + dy * dy);
    }
};
pub const TileRect = struct {
    x: u8,
    y: u8,
    w: u8,
    h: u8,

    pub fn intersect(r1: TileRect, r2: TileRect) bool {
        return r1.x < r2.x + r2.w and r1.x + r1.w > r2.x and
            r1.y < r2.y + r2.h and r1.y + r1.h > r2.y;
    }

    pub fn center(r: TileRect) TilePosition {
        return .{ .x = r.x + r.w / 2, .y = r.y + r.h / 2 };
    }

    pub fn fromCenter(c: TilePosition, w: u8) TileRect {
        return .{
            .x = c.x -| w,
            .y = c.y -| w,
            .w = 2 * w + 1,
            .h = 2 * w + 1,
        };
    }

    pub fn contains(self: TileRect, pos: TilePosition) bool {
        return self.x <= pos.x and pos.x < self.x + self.w and
            self.y <= pos.y and pos.y < self.y + self.h;
    }
};
pub const WantToMove = struct { TilePosition };
pub const WantToAttack = struct { ecs.Entity };
pub const ViewField = struct { TileRect };
pub const PlayerView = struct {};
pub const Item = struct {};
pub const Carried = struct {};
pub const Healing = struct { v: u8 };
pub const Damage = struct { v: u8 };
