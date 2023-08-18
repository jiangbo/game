pub usingnamespace @cImport({
    @cInclude("SDL.h");
    @cInclude("SDL_ttf.h");
});

const self = @This();
const std = @import("std");
pub fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, self.SDL_GetError());
    @panic(std.mem.sliceTo(str orelse "unknown error", 0));
}
