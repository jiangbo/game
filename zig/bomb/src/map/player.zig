const std = @import("std");
const engine = @import("../engine.zig");
const core = @import("core.zig");

const speedUnit = 1000;

pub const Player = struct {
    x: usize,
    y: usize,
    bombNumber: usize = 0,
    maxBombNumber: usize = 1,
    maxBombLength: usize = 1,
    direction: ?core.Direction,
    alive: bool = true,
    type: core.MapType,

    pub fn genEnemy(x: usize, y: usize) Player {
        const rand = engine.random(4);
        return init(x, y, .enemy, @enumFromInt(rand));
    }

    pub fn genPlayer(x: usize, y: usize, t: core.MapType) Player {
        return init(x, y, t, null);
    }

    fn init(x: usize, y: usize, t: core.MapType, d: ?core.Direction) Player {
        return Player{
            .x = x * core.getMapUnit() * speedUnit,
            .y = y * core.getMapUnit() * speedUnit,
            .type = t,
            .direction = d,
        };
    }

    pub fn getCell(self: Player) engine.Vector {
        const unit = core.getMapUnit();
        return .{
            .x = (self.x / speedUnit + (unit / 2)) / unit,
            .y = (self.y / speedUnit + (unit / 2)) / unit,
        };
    }

    pub fn draw(self: Player) void {
        const x = self.x / speedUnit;
        core.drawXY(self.type, x, self.y / speedUnit);
    }

    pub fn toCollisionRec(self: Player) engine.Rectangle {
        return engine.Rectangle{
            .x = self.x / speedUnit + 5,
            .y = self.y / speedUnit + 5,
            .width = core.getMapUnit() - 10,
            .height = core.getMapUnit() - 7,
        };
    }
};
