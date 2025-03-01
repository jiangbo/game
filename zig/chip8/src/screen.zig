const std = @import("std");
const c = @cImport(@cInclude("SDL.h"));

const WIDTH: c_int = 64;
const HEIGHT: c_int = 32;
const BUFFER_SIZE = WIDTH * HEIGHT;

pub const Screen = struct {
    scale: u8 = 10,
    buffer: [BUFFER_SIZE]bool = undefined,
    needRender: bool = true,
    window: *c.SDL_Window = undefined,
    renderer: *c.SDL_Renderer = undefined,
    texture: *c.SDL_Texture = undefined,

    pub fn init(self: *Screen) void {
        if (c.SDL_Init(c.SDL_INIT_EVERYTHING) < 0)
            @panic("sdl init failed");

        const center = c.SDL_WINDOWPOS_CENTERED;
        self.window = c.SDL_CreateWindow("chip8", center, center, //
            WIDTH * self.scale, HEIGHT * self.scale, c.SDL_WINDOW_SHOWN) //
        orelse @panic("create window failed");

        self.renderer = c.SDL_CreateRenderer(self.window, -1, 0) //
        orelse @panic("create renderer failed");

        self.texture = c.SDL_CreateTexture(self.renderer, //
            c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_STREAMING, //
            WIDTH, HEIGHT) orelse @panic("create texture failed");

        _ = c.SDL_SetRenderTarget(self.renderer, self.texture);
        _ = c.SDL_RenderSetLogicalSize(self.renderer, WIDTH, HEIGHT);
    }

    pub fn update(self: *Screen, fps: u32) void {
        defer c.SDL_Delay(1000 / fps);
        if (!self.needRender) return;

        _ = c.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_SetRenderDrawColor(self.renderer, 255, 255, 255, 255);

        for (self.buffer, 0..) |value, index| {
            if (value) {
                const x: c_int = @intCast(index % WIDTH);
                const y: c_int = @intCast(@divTrunc(index, WIDTH));
                _ = c.SDL_RenderDrawPoint(self.renderer, x, y);
            }
        }
        c.SDL_RenderPresent(self.renderer);
        self.needRender = false;
    }

    pub fn setIndex(self: *Screen, i: usize) bool {
        self.needRender = true;
        const index = if (i >= BUFFER_SIZE) i % BUFFER_SIZE else i;
        self.buffer[index] = !self.buffer[index];
        return self.buffer[index];
    }

    pub fn setPixel(self: *Screen, x: usize, y: usize) bool {
        return self.setIndex(x + y * WIDTH);
    }

    pub fn clear(self: *Screen) void {
        @memset(&self.buffer, false);
        self.needRender = true;
    }

    pub fn deinit(self: *Screen) void {
        c.SDL_DestroyTexture(self.texture);
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }
};
