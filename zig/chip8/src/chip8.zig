const cpu = @import("cpu.zig");
const memory = @import("memory.zig");
const screen = @import("screen.zig");
const keypad = @import("keypad.zig");

const ENTRY = 0x200;
const HZ = 500;
const FPS = 60;

pub const Emulator = struct {
    cpu: cpu.CPU,
    memory: memory.Memory,
    screen: screen.Screen,
    keypad: keypad.Keypad,

    pub fn new(rom: []const u8) Emulator {
        return Emulator{
            .cpu = cpu.CPU.new(ENTRY),
            .memory = memory.Memory.new(rom, ENTRY),
            .screen = screen.Screen{},
            .keypad = keypad.Keypad{},
        };
    }

    pub fn run(self: *Emulator) void {
        self.screen.init();
        defer self.screen.deinit();
        self.memory.screen = &self.screen;
        self.memory.keypad = &self.keypad;

        var index: usize = 0;
        while (self.keypad.poll()) : (index += 1) {
            for (0..(HZ / FPS)) |_|
                self.cpu.cycle(&self.memory);

            self.screen.update(FPS);
            self.cpu.tick();
        }
    }
};
