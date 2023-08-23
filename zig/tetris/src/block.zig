const std = @import("std");
const display = @import("display.zig");

pub const tetriminoes: [7]Tetrimino = label: {
    var arr: [7]Tetrimino = undefined;
    // I
    arr[0] = .{ .y = -1, .value = .{
        .{ 0, 1, 1, 1, 2, 1, 3, 1 },
        .{ 2, 0, 2, 1, 2, 2, 2, 3 },
        .{ 0, 2, 1, 2, 2, 2, 3, 2 },
        .{ 1, 0, 1, 1, 1, 2, 1, 3 },
    }, .color = 0x00ffffff };
    // J
    arr[1] = .{ .value = .{
        .{ 0, 0, 0, 1, 1, 1, 2, 1 },
        .{ 1, 0, 2, 0, 1, 1, 1, 2 },
        .{ 0, 1, 1, 1, 2, 1, 2, 2 },
        .{ 1, 0, 1, 1, 0, 2, 1, 2 },
    }, .color = 0x0000ffff };
    // L
    arr[2] = .{ .value = .{
        .{ 2, 0, 0, 1, 1, 1, 2, 1 },
        .{ 1, 0, 1, 1, 1, 2, 2, 2 },
        .{ 0, 1, 1, 1, 2, 1, 0, 2 },
        .{ 0, 0, 1, 0, 1, 1, 1, 2 },
    }, .color = 0xffaa00ff };
    // O
    arr[3] = .{ .value = .{
        .{ 1, 0, 2, 0, 1, 1, 2, 1 },
        .{ 1, 0, 2, 0, 1, 1, 2, 1 },
        .{ 1, 0, 2, 0, 1, 1, 2, 1 },
        .{ 1, 0, 2, 0, 1, 1, 2, 1 },
    }, .color = 0xffff00ff };
    // S
    arr[4] = .{ .value = .{
        .{ 1, 0, 2, 0, 0, 1, 1, 1 },
        .{ 1, 0, 1, 1, 2, 1, 2, 2 },
        .{ 1, 1, 2, 1, 0, 2, 1, 2 },
        .{ 0, 0, 0, 1, 1, 1, 1, 2 },
    }, .color = 0x00ff00ff };
    // T
    arr[5] = .{ .value = .{
        .{ 1, 0, 0, 1, 1, 1, 2, 1 },
        .{ 1, 0, 1, 1, 2, 1, 1, 2 },
        .{ 0, 1, 1, 1, 2, 1, 1, 2 },
        .{ 1, 0, 0, 1, 1, 1, 1, 2 },
    }, .color = 0x9900ffff };
    // Z
    arr[6] = .{ .value = .{
        .{ 0, 0, 1, 0, 1, 1, 2, 1 },
        .{ 2, 0, 1, 1, 2, 1, 1, 2 },
        .{ 0, 1, 1, 1, 1, 2, 2, 2 },
        .{ 1, 0, 0, 1, 1, 1, 0, 2 },
    }, .color = 0xff0000ff };
    break :label arr;
};

pub const Facing = enum { North, East, South, West };
pub const Tetrimino = struct {
    x: i32 = 3,
    y: i32 = 0,
    facing: Facing = .North,
    value: [4][8]u8 = undefined,
    color: u32,
    solid: bool = false,

    pub fn position(self: *const Tetrimino) [8]u8 {
        return self.value[@intFromEnum(self.facing)];
    }

    pub fn random(rand: *std.rand.DefaultPrng) Tetrimino {
        const len = tetriminoes.len;
        return tetriminoes[rand.random().uintLessThan(usize, len)];
    }

    pub fn rotate(self: *Tetrimino) void {
        const int: u8 = @intFromEnum(self.facing);
        const len = std.enums.values(Facing).len;
        self.facing = @enumFromInt(int + 1 % len);
    }

    pub fn locateIn(self: *Tetrimino) void {
        const pos = self.position();

        const minx = @min(@min(@min(pos[0], pos[2]), pos[4]), pos[6]);
        if (self.x + minx < 0) self.x -= self.x + minx;

        const maxx = @max(@max(@max(pos[0], pos[2]), pos[4]), pos[6]);
        const x = self.x + maxx - display.WIDTH;
        if (x >= 0) self.x -= x + 1;
    }
};
