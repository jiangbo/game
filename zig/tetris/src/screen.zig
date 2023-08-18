const std = @import("std");
const c = @import("c.zig");

pub const WIDTH = 10;
pub const HEIGHT = 20;

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

    pub fn draw(self: *Screen, x: usize, y: usize, rgba: u32) void {
        const r: u8 = @truncate((rgba >> 24) & 0xff);
        const g: u8 = @truncate((rgba >> 16) & 0xff);
        const b: u8 = @truncate((rgba >> 8) & 0xff);
        const a: u8 = @truncate((rgba >> 0) & 0xff);
        _ = c.SDL_SetRenderDrawColor(self.renderer, r, g, b, a);
        self.fillRect(x, y);
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

    pub fn hasSolid(self: *Screen, x: usize, y: usize) bool {
        if (x >= WIDTH) return false;
        return y >= HEIGHT or self.buffer[x][y] != 0;
    }

    fn fillRect(self: *Screen, x: usize, y: usize) void {
        const scale = 40;
        const border = 2;
        const rect = c.SDL_Rect{
            .x = @intCast(x * scale + border + 20),
            .y = @intCast(y * scale + border + 20),
            .w = @intCast(scale - border * 2),
            .h = @intCast(scale - border * 2),
        };
        _ = c.SDL_RenderFillRect(self.renderer, &rect);
    }

    pub fn display(self: *Screen, score: usize) void {
        self.setColor(0x3b, 0x3b, 0x3b);
        _ = c.SDL_RenderClear(self.renderer);
        for (0..WIDTH) |row| {
            for (0..HEIGHT) |col| {
                const color = self.buffer[row][col];
                if (color == 0) {
                    self.setColor(40, 40, 40);
                    self.fillRect(row, col);
                } else {
                    self.draw(row, col, color);
                }
            }
        }
        self.drawText("Score", 500, 50);
        self.setColor(40, 40, 40);
        var r = c.SDL_Rect{ .x = 440, .y = 120, .w = 240, .h = 100 };
        _ = c.SDL_RenderFillRect(self.renderer, &r);

        var buf: [9]u8 = undefined;
        var text = std.fmt.bufPrintZ(&buf, "{:0>7}", .{score}) catch unreachable;
        self.drawText(text, 480, 145);
        self.drawText("Next", 510, 280);
        r = c.SDL_Rect{ .x = 440, .y = 360, .w = 240, .h = 200 };
        _ = c.SDL_RenderFillRect(self.renderer, &r);
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

    pub fn present(self: *Screen, fps: u32) void {
        c.SDL_RenderPresent(self.renderer);
        c.SDL_Delay(1000 / fps);
    }

    pub fn deinit(self: *Screen) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.TTF_Quit();
        c.SDL_Quit();
    }

    fn setColor(self: *Screen, r: u8, g: u8, b: u8) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, r, g, b, 0xff);
    }
};
