const c = @import("c.zig");
const std = @import("std");
const display = @import("display.zig");
const app = @import("app.zig");

pub fn main() !void {
    var screen = display.Screen{};
    screen.init();
    defer screen.deinit();
    var game = app.Game.new();
    _ = c.SDL_AddTimer(500, tick, null);

    mainLoop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT)
                break :mainLoop;

            if (game.over) break;
            handleInput(&game, &screen, &event);
        }

        screen.update(game.score, game.over);
        game.drawCurrent(&screen);
        screen.present();
    }
}

fn handleInput(game: *app.Game, screen: *display.Screen, event: *c.SDL_Event) void {
    if (event.type != c.SDL_KEYDOWN) return;

    const code = event.key.keysym.sym;
    switch (code) {
        c.SDLK_LEFT => game.moveLeft(screen),
        c.SDLK_RIGHT => game.moveRight(screen),
        c.SDLK_UP => game.rotate(screen),
        c.SDLK_DOWN => game.moveDown(screen),
        c.SDLK_SPACE => game.rotate(screen),
        else => return,
    }
}

fn tick(interval: u32, _: ?*anyopaque) callconv(.C) u32 {
    var event: c.SDL_Event = std.mem.zeroes(c.SDL_Event);
    event.type = c.SDL_KEYDOWN;
    event.key.keysym.sym = c.SDLK_DOWN;
    _ = c.SDL_PushEvent(&event);
    return interval;
}
