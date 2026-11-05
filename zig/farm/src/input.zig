const std = @import("std");
const zhu = @import("zhu");

pub const Command = enum {
    left,
    right,
    up,
    down,
    pause,
    interact,
    inventory,
    hotbar,
    hotbar1,
    hotbar2,
    hotbar3,
    hotbar4,
    hotbar5,
    hotbar6,
    hotbar7,
    hotbar8,
    hotbar9,
    hotbar10,
};

const Entry = struct { type: Command, value: []const zhu.key.Code };
const zon: []const Entry = @import("zon/input.zon");
const keys = zhu.enums.fromEntries(Entry, zon);

pub var mouseCaptured: bool = false;

pub fn held(command: Command) bool {
    return zhu.key.anyHeld(keys.get(command));
}

pub fn pressed(command: Command) bool {
    return zhu.key.anyPressed(keys.get(command));
}

pub fn released(command: Command) bool {
    return zhu.key.anyReleased(keys.get(command));
}

pub fn hotbarPressed() ?u8 {
    const first: usize = @backingInt(Command.hotbar1);
    const last: usize = @backingInt(Command.hotbar10);
    for (first..last + 1) |value| {
        const command: Command = @fromBackingInt(@intCast(value));
        if (pressed(command)) return @intCast(value - first);
    }
    return null;
}
