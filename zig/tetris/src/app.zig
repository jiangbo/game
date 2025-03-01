const std = @import("std");
const Screen = @import("display.zig").Screen;
const Tetrimino = @import("block.zig").Tetrimino;

pub const Game = struct {
    current: Tetrimino,
    next: Tetrimino,
    prng: std.rand.DefaultPrng,
    over: bool = false,
    score: usize = 0,

    pub fn new() Game {
        const seed = @as(u64, @intCast(std.time.timestamp()));
        var rand = std.rand.DefaultPrng.init(seed);
        return Game{
            .current = Tetrimino.random(&rand),
            .next = Tetrimino.random(&rand),
            .prng = rand,
        };
    }

    pub fn drawCurrent(self: *Game, screen: *Screen) void {
        _ = draw(&self.current, screen, self.current.x, self.current.y);
        _ = draw(&self.next, screen, 12, 10);
    }

    pub fn moveLeft(self: *Game, screen: *Screen) void {
        _ = self.move(screen, -1, 0);
    }

    pub fn moveRight(self: *Game, screen: *Screen) void {
        _ = self.move(screen, 1, 0);
    }

    pub fn moveDown(self: *Game, screen: *Screen) void {
        if (self.move(screen, 0, 1)) {
            self.current.solid = true;
            const cur = &self.current;
            const lines = draw(cur, screen, cur.x, cur.y);
            self.score += computeScore(lines);

            self.current = self.next;
            self.next = Tetrimino.random(&self.prng);
            if (self.isFit(screen)) self.over = true;
        }
    }

    fn move(self: *Game, screen: *const Screen, x: i8, y: i8) bool {
        self.current.x = self.current.x + x;
        self.current.y = self.current.y + y;
        self.current.locateIn();

        return if (self.isFit(screen)) {
            _ = self.move(screen, -x, -y);
            return true;
        } else false;
    }

    pub fn rotate(self: *Game, screen: *Screen) void {
        var temp = self.current;
        self.current.rotate();
        self.current.locateIn();
        if (self.isFit(screen)) {
            self.current = temp;
        }
    }

    fn isFit(self: *const Game, screen: *const Screen) bool {
        const value = self.current.position();
        var index: usize = 0;
        while (index < value.len) : (index += 2) {
            const col = self.current.y + value[index + 1];
            if (col < 0) return true;
            const row: usize = @intCast(self.current.x + value[index]);
            if (screen.hasSolid(row, @intCast(col))) return true;
        }
        return false;
    }
};

fn draw(block: *const Tetrimino, screen: *Screen, x: i32, y: i32) u8 {
    const value = block.position();
    var index: usize = 0;
    var completed: u8 = 0;
    while (index < value.len) : (index += 2) {
        const row: usize = @intCast(x + value[index]);
        const col: usize = @intCast(y + value[index + 1]);
        if (block.solid) {
            if (screen.drawSolid(row, col, block.color))
                completed += 1;
        } else {
            screen.draw(row, col, block.color);
        }
    }
    return completed;
}

fn computeScore(lines: u8) usize {
    return switch (lines) {
        1 => 100,
        2 => 300,
        3 => 600,
        4 => 1000,
        else => 0,
    };
}
