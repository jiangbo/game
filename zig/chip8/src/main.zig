const std = @import("std");
const chip8 = @import("chip8.zig");

pub fn main() !void {
    const rom = @embedFile("roms/1-chip8-logo.ch8");
    // const rom = @embedFile("2-ibm-logo.ch8");
    // const rom = @embedFile("3-corax+.ch8");
    // const rom = @embedFile("4-flags.ch8");
    // const rom = @embedFile("5-quirks.ch8");
    // const rom = @embedFile("6-keypad.ch8");
    // const rom = @embedFile("tetris.rom");
    var emulator = chip8.Emulator.new(rom);
    emulator.run();
}
