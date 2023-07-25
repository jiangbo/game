const std = @import("std");
const cpu = @import("cpu.zig");
const mem = @import("memory.zig");
const screen = @import("screen.zig");
const keypad = @import("keypad.zig");

const ENTRY = 0x200;
const HZ = 500;
const FPS = 60;

pub const Emulator = struct {
    cpu: cpu.CPU,
    memory: mem.Memory,
    screen: screen.Screen,
    keypad: keypad.Keypad,

    pub fn new(rom: []const u8) Emulator {
        const seed = @as(u64, @intCast(std.time.timestamp()));
        var prng = std.rand.DefaultPrng.init(seed);
        return Emulator{
            .cpu = cpu.CPU{ .pc = ENTRY, .prng = prng },
            .memory = mem.Memory.new(rom, ENTRY),
            .screen = screen.Screen.new(),
            .keypad = keypad.Keypad.new(),
        };
    }

    pub fn run(self: *Emulator) void {
        self.memory.screen = &self.screen;
        self.memory.keypad = &self.keypad;
        self.screen.init();
        defer self.screen.deinit();

        while (self.keypad.poll()) {
            for (0..(HZ / FPS)) |_|
                self.cpu.cycle(&self.memory);
            self.screen.update(FPS);
            self.cpu.tick();
        }
    }
};
