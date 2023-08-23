const c = @import("c.zig");
const fmt = @import("std").fmt;

pub const WIDTH = 10;
pub const HEIGHT = 20;

const FPS = 60;
const SCALE = 40; // 放大倍数
const BORDER = 2; // 边框

pub const Screen = struct {
    line: usize = HEIGHT,
    buffer: [WIDTH][HEIGHT]u32 = undefined,
    window: *c.SDL_Window = undefined,
    renderer: *c.SDL_Renderer = undefined,
    font: *c.TTF_Font = undefined,

    pub fn init(self: *Screen) void {
        if (c.SDL_Init(c.SDL_INIT_EVERYTHING) < 0) c.sdlPanic();
        if (c.TTF_Init() < 0) c.sdlPanic();

        self.font = c.TTF_OpenFont("clacon.ttf", 60) orelse c.sdlPanic();
        const center = c.SDL_WINDOWPOS_CENTERED;
        self.window = c.SDL_CreateWindow("俄罗斯方块", center, center, //
            700, 850, c.SDL_WINDOW_SHOWN) orelse c.sdlPanic();

        self.renderer = c.SDL_CreateRenderer(self.window, -1, 0) //
        orelse c.sdlPanic();
    }

    pub fn update(self: *Screen, score: usize, over: bool) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0x3b, 0x3b, 0x3b, 0xff);
        _ = c.SDL_RenderClear(self.renderer);
        for (0..WIDTH) |row| {
            for (0..HEIGHT) |col| {
                var color = self.buffer[row][col];
                if (color == 0) color = 0x404040ff;
                self.draw(row, col, color);
            }
        }

        self.drawScore(score);
        self.drawText("Next", 510, 280);
        var r = c.SDL_Rect{ .x = 440, .y = 360, .w = 240, .h = 200 };
        _ = c.SDL_RenderFillRect(self.renderer, &r);
        if (over) self.drawText("GAME OVER", 460, 650);
    }

    pub fn draw(self: *Screen, x: usize, y: usize, rgba: u32) void {
        const r: u8 = @truncate((rgba >> 24) & 0xff);
        const g: u8 = @truncate((rgba >> 16) & 0xff);
        const b: u8 = @truncate((rgba >> 8) & 0xff);
        const a: u8 = @truncate((rgba >> 0) & 0xff);

        _ = c.SDL_SetRenderDrawColor(self.renderer, r, g, b, a);
        const rect = c.SDL_Rect{
            .x = @intCast(x * SCALE + BORDER + 20),
            .y = @intCast(y * SCALE + BORDER + 20),
            .w = @intCast(SCALE - BORDER * 2),
            .h = @intCast(SCALE - BORDER * 2),
        };
        _ = c.SDL_RenderFillRect(self.renderer, &rect);
    }

    pub fn drawSolid(self: *Screen, x: usize, y: usize, rgba: u32) bool {
        self.draw(x, y, rgba);
        self.buffer[x][y] = rgba;
        self.line = @min(self.line, y);
        for (0..WIDTH) |row| {
            if (self.buffer[row][y] == 0) return false;
        }
        return self.clearRow(y);
    }

    fn clearRow(self: *Screen, col: usize) bool {
        var y = col;
        while (y >= self.line) : (y -= 1) {
            for (0..WIDTH) |x| {
                self.buffer[x][y] = self.buffer[x][y - 1];
            }
        }
        self.line += 1;
        return true;
    }

    fn drawScore(self: *Screen, score: usize) void {
        self.drawText("Score", 500, 50);

        _ = c.SDL_SetRenderDrawColor(self.renderer, 40, 40, 40, 0xff);
        var r = c.SDL_Rect{ .x = 440, .y = 120, .w = 240, .h = 100 };
        _ = c.SDL_RenderFillRect(self.renderer, &r);
        var buf: [9]u8 = undefined;
        var text = fmt.bufPrintZ(&buf, "{:0>7}", .{score});
        self.drawText(text catch unreachable, 480, 145);
    }

    pub fn drawText(self: *Screen, text: [*c]const u8, x: i32, y: i32) void {
        var surface = c.TTF_RenderUTF8_Solid(self.font, text, //
            .{ .r = 0xff, .g = 0xff, .b = 0xff, .a = 255 });
        var texture = c.SDL_CreateTextureFromSurface(self.renderer, //
            surface) orelse c.sdlPanic();
        var r = c.SDL_Rect{ .x = x, .y = y, .w = 0, .h = 0 };
        _ = c.SDL_QueryTexture(texture, null, null, &r.w, &r.h);
        _ = c.SDL_RenderCopy(self.renderer, texture, null, &r);
        c.SDL_FreeSurface(surface);
        c.SDL_DestroyTexture(texture);
    }

    pub fn hasSolid(self: *const Screen, x: usize, y: usize) bool {
        if (x >= WIDTH) return false;
        return y >= HEIGHT or self.buffer[x][y] != 0;
    }

    pub fn present(self: *Screen) void {
        c.SDL_RenderPresent(self.renderer);
        c.SDL_Delay(1000 / FPS);
    }

    pub fn deinit(self: *Screen) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.TTF_Quit();
        c.SDL_Quit();
    }
};
