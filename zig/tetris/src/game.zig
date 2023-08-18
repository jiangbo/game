const std = @import("std");
const Screen = @import("screen.zig").Screen;
const Tetrimino = @import("block.zig").Tetrimino;

pub const Game = struct {
    over: bool = false,
    current: Tetrimino,
    next: Tetrimino,
    prng: std.rand.DefaultPrng,
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

    pub fn update(self: *Game, screen: *Screen) void {
        self.moveDown(screen);
        self.drawTetrimino(screen);
    }

    pub fn drawTetrimino(self: *Game, screen: *Screen) void {
        self.draw(&self.current, screen, self.current.x, self.current.y);
        self.draw(&self.next, screen, 12, 10);
        if (self.current.solid) {
            self.current = self.next;
            self.next = Tetrimino.random(&self.prng);
            if (self.hasSolid(screen)) self.over = true;
        }
    }

    fn draw(self: *Game, block: *Tetrimino, screen: *Screen, x: i32, y: i32) void {
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
        self.computeScore(completed);
    }

    fn computeScore(self: *Game, completed: u8) void {
        self.score += switch (completed) {
            1 => 100,
            2 => 300,
            3 => 600,
            4 => 1000,
            else => 0,
        };
    }

    pub fn moveLeft(self: *Game, screen: *Screen) void {
        self.move(-1, 0);
        if (self.hasSolid(screen)) {
            self.move(1, 0);
        }
    }

    pub fn moveRight(self: *Game, screen: *Screen) void {
        self.move(1, 0);
        if (self.hasSolid(screen)) {
            self.move(-1, 0);
        }
    }

    pub fn moveDown(self: *Game, screen: *Screen) void {
        self.move(0, 1);
        if (self.hasSolid(screen)) {
            self.current.solid = true;
            self.move(0, -1);
        }
    }

    fn move(self: *Game, x: i8, y: i8) void {
        self.current.x = self.current.x + x;
        self.current.y = self.current.y + y;
        self.current.locateIn();
    }

    pub fn rotate(self: *Game, screen: *Screen) void {
        var temp = self.current;
        self.current.rotate();
        self.current.locateIn();
        if (self.hasSolid(screen)) {
            self.current = temp;
        }
    }

    fn hasSolid(self: *Game, screen: *Screen) bool {
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
