const std = @import("std");
const Screen = @import("screen.zig").Screen;
const Keypad = @import("keypad.zig").Keypad;

pub const Memory = struct {
    ram: [4096]u8 = undefined,
    stack: [16]u16 = undefined,
    sp: u8 = 0,
    screen: *Screen = undefined,
    keypad: *Keypad = undefined,

    pub fn new(rom: []const u8, entry: u16) Memory {
        var memory = Memory{};
        @memcpy(memory.ram[0..fonts.len], &fonts);
        @memcpy(memory.ram[entry .. entry + rom.len], rom);
        return memory;
    }

    pub fn load(self: *Memory, pc: u16) u16 {
        const high: u8 = self.ram[pc];
        return (@as(u16, high) << 8) | self.ram[pc + 1];
    }

    pub fn clearScreen(self: *Memory) void {
        var screen1 = self.screen;
        screen1.clear();
    }

    pub fn setPixel(self: *Memory, x: usize, y: usize) bool {
        return self.screen.setPixel(x, y);
    }

    pub fn set(self: *Memory, index: usize, value: u8) void {
        self.ram[index] = value;
    }

    pub fn isPress(self: *Memory, index: usize) bool {
        // std.log.info("is press index: {any}, result: {}", .{ index, self.keypad.buffer[index] });
        return self.keypad.buffer[index];
    }

    pub fn getPress(self: *Memory) ?u8 {
        // std.log.info("get press: {any}", .{self.keypad.buffer});
        for (self.keypad.buffer, 0..) |code, index| {
            if (code) return @truncate(index);
        }
        return null;
    }

    pub fn get(self: *Memory, index: usize) u8 {
        return self.ram[index];
    }

    pub fn push(self: *Memory, value: u16) void {
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    pub fn pop(self: *Memory) u16 {
        self.sp -= 1;
        return self.stack[self.sp];
    }
};

const fonts = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xe0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};
