const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");

pub const KeyCode = sk.app.Keycode;

pub var mousePosition: math.Vector = .zero;
pub var mouseScrollY: f32 = 0;
pub var anyRelease: bool = false;

pub fn event(ev: *const sk.app.Event) void {
    const keyCode: usize = @intCast(@intFromEnum(ev.key_code));
    const buttonCode: usize = @intCast(@intFromEnum(ev.mouse_button));
    switch (ev.type) {
        .KEY_DOWN => key.state.set(keyCode),
        .KEY_UP => {
            key.state.unset(keyCode);
            anyRelease = true;
        },
        .MOUSE_MOVE => mousePosition = .xy(ev.mouse_x, ev.mouse_y),
        .MOUSE_DOWN => mouse.state.set(buttonCode),
        .MOUSE_UP => {
            mouse.state.unset(buttonCode);
            anyRelease = true;
        },
        .MOUSE_SCROLL => mouseScrollY += ev.scroll_y,
        .ICONIFIED, .UNFOCUSED => {
            key.state = .initEmpty();
            mouse.state = .initEmpty();
        },
        else => {},
    }
}

pub const key = struct {
    pub var lastState: std.StaticBitSet(512) = .initEmpty();
    pub var state: std.StaticBitSet(512) = .initEmpty();

    pub fn down(keyCode: KeyCode) bool {
        return state.isSet(@intCast(@intFromEnum(keyCode)));
    }

    pub fn pressed(keyCode: KeyCode) bool {
        const code: usize = @intCast(@intFromEnum(keyCode));
        return !lastState.isSet(code) and state.isSet(code);
    }

    pub fn released(keyCode: KeyCode) bool {
        const code: usize = @intCast(@intFromEnum(keyCode));
        return lastState.isSet(code) and !state.isSet(code);
    }

    pub fn anyDown(keys: []const KeyCode) bool {
        for (keys) |k| if (down(k)) return true;
        return false;
    }

    pub fn anyPressed(keys: []const KeyCode) bool {
        for (keys) |k| if (pressed(k)) return true;
        return false;
    }

    pub fn anyReleased(keys: []const KeyCode) bool {
        for (keys) |k| if (released(k)) return true;
        return false;
    }
};

pub const mouse = struct {
    pub var lastState: std.StaticBitSet(3) = .initEmpty();
    pub var state: std.StaticBitSet(3) = .initEmpty();

    pub fn down(button: sk.app.Mousebutton) bool {
        return state.isSet(@intCast(@intFromEnum(button)));
    }

    pub fn pressed(button: sk.app.Mousebutton) bool {
        const code: usize = @intCast(@intFromEnum(button));
        return !lastState.isSet(code) and state.isSet(code);
    }

    pub fn released(button: sk.app.Mousebutton) bool {
        const code: usize = @intCast(@intFromEnum(button));
        return lastState.isSet(code) and !state.isSet(code);
    }

    pub fn anyReleased(buttons: []const sk.app.Mousebutton) bool {
        for (buttons) |button| if (released(button)) return true;
        return false;
    }
};
