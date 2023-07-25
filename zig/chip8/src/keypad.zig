const c = @cImport(@cInclude("SDL.h"));
const std = @import("std");

pub const Keypad = struct {
    buffer: [16]bool = undefined,
    event: c.SDL_Event = undefined,
    pub fn new() Keypad {
        return Keypad{
            .buffer = std.mem.zeroes([16]bool),
        };
    }

    pub fn poll(self: *Keypad) bool {
        const start = std.time.milliTimestamp();
        _ = start;
        while (c.SDL_PollEvent(&self.event) > 0) {
            if (self.event.type == c.SDL_QUIT) return false;

            const flag = if (self.event.type == c.SDL_KEYDOWN) true //
            else if (self.event.type == c.SDL_KEYUP) false //
            else continue;
            // std.log.info("event: {}", .{self.event.key.keysym});
            self.setBuffer(self.event.key.keysym.sym, flag);
        }

        const end = std.time.milliTimestamp();
        _ = end;
        // std.log.info("ms: {}", .{end - start});
        return true;
    }

    fn setBuffer(self: *Keypad, code: i32, value: bool) void {
        switch (code) {
            c.SDLK_x => self.buffer[0] = value,
            c.SDLK_1 => self.buffer[1] = value,
            c.SDLK_2 => self.buffer[2] = value,
            c.SDLK_3 => self.buffer[3] = value,
            c.SDLK_q => self.buffer[4] = value,
            c.SDLK_w => self.buffer[5] = value,
            c.SDLK_e => self.buffer[6] = value,
            c.SDLK_a => self.buffer[7] = value,
            c.SDLK_s => self.buffer[8] = value,
            c.SDLK_d => self.buffer[9] = value,
            c.SDLK_z => self.buffer[10] = value,
            c.SDLK_c => self.buffer[11] = value,
            c.SDLK_4 => self.buffer[12] = value,
            c.SDLK_r => self.buffer[13] = value,
            c.SDLK_f => self.buffer[14] = value,
            c.SDLK_v => self.buffer[15] = value,
            else => return,
        }
        // buffer.* = value;
        // std.log.info("buffer:{any}", .{self.buffer});
    }
};
