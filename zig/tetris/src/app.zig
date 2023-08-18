const std = @import("std");
const c = @import("c.zig");
const screen = @import("screen.zig");
const game = @import("game.zig");

const FPS = 60;

pub const Tetris = struct {
    game: game.Game,
    screen: screen.Screen,

    pub fn new() Tetris {
        return Tetris{
            .game = game.Game.new(),
            .screen = screen.Screen{},
        };
    }

    pub fn run(self: *Tetris) void {
        self.screen.init();
        defer self.screen.deinit();
        _ = c.SDL_AddTimer(500, tick, null);

        mainLoop: while (true) {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event) != 0) {
                if (event.type == c.SDL_QUIT)
                    break :mainLoop;
                if (self.game.over) break;
                if (event.type == c.SDL_USEREVENT)
                    self.game.update(&self.screen);

                self.handleInput(&event);
            }

            self.screen.display(self.game.score);
            self.game.drawTetrimino(&self.screen);
            if (self.game.over)
                self.screen.drawText("GAME OVER", 460, 650);
            self.screen.present(FPS);
        }
    }

    fn handleInput(self: *Tetris, event: *c.SDL_Event) void {
        if (event.type != c.SDL_KEYDOWN) return;

        const code = event.key.keysym.sym;
        switch (code) {
            c.SDLK_LEFT => self.game.moveLeft(&self.screen),
            c.SDLK_RIGHT => self.game.moveRight(&self.screen),
            c.SDLK_UP => self.game.rotate(&self.screen),
            c.SDLK_DOWN => self.game.moveDown(&self.screen),
            c.SDLK_SPACE => self.game.rotate(&self.screen),
            else => return,
        }
    }
};

fn tick(interval: u32, param: ?*anyopaque) callconv(.C) u32 {
    _ = param;
    var event: c.SDL_Event = undefined;
    event.type = c.SDL_USEREVENT;
    _ = c.SDL_PushEvent(&event);
    return interval;
}
