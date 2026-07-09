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
const Mouse = zhu.mouse.Button;

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

pub fn mouseHeld(button: Mouse) bool {
    if (mouseCaptured) return false;
    return zhu.mouse.held(button);
}

pub fn mousePressed(button: Mouse) bool {
    if (mouseCaptured) return false;
    return zhu.mouse.pressed(button);
}

pub fn mouseReleased(button: Mouse) bool {
    if (mouseCaptured) return false;
    return zhu.mouse.released(button);
}

pub fn hotbarPressed() ?u8 {
    const first: usize = @intFromEnum(Command.hotbar1);
    const last: usize = @intFromEnum(Command.hotbar10);
    for (first..last + 1) |value| {
        const command: Command = @enumFromInt(value);
        if (pressed(command)) return @intCast(value - first);
    }
    return null;
}
