const std = @import("std");
const sk = @import("sokol");
const math = @import("math.zig");

pub const Event = sk.app.Event;

pub const Timer = struct {
    finished: bool = false,
    duration: f32,
    elapsed: f32 = 0,

    pub fn init(duration: f32) Timer {
        return Timer{ .duration = duration };
    }

    pub fn update(self: *Timer, delta: f32) void {
        if (self.finished) return;
        self.elapsed += delta;
        if (self.elapsed >= self.duration) self.finished = true;
    }

    pub fn isRunningAfterUpdate(self: *Timer, delta: f32) bool {
        return !self.isFinishedAfterUpdate(delta);
    }

    pub fn isFinishedAfterUpdate(self: *Timer, delta: f32) bool {
        self.update(delta);
        return self.finished;
    }

    pub fn reset(self: *Timer) void {
        self.finished = false;
        self.elapsed = 0;
    }

    pub fn isRunning(self: *const Timer) bool {
        return !self.finished;
    }
};

pub var size: math.Vector = .zero;

pub fn displayText(x: f32, y: f32, text: [:0]const u8) void {
    sk.debugtext.canvas(sk.app.widthf() * 0.4, sk.app.heightf() * 0.4);
    sk.debugtext.origin(x, y);
    sk.debugtext.home();

    sk.debugtext.font(0);
    sk.debugtext.color3b(0xff, 0xff, 0xff);
    sk.debugtext.puts(text);
}

pub fn endDisplayText() void {
    sk.debugtext.draw();
}

pub fn exit() void {
    sk.app.quit();
}
pub const run = sk.app.run;
