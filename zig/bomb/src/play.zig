const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

const playerSpeed = 100;

pub const Gameplay = struct {
    map: map.Map,
    mode: bool,

    pub fn init(mode: bool, level: usize) ?Gameplay {
        const m = map.Map.init(mode, level) orelse return null;
        return Gameplay{ .map = m, .mode = mode };
    }

    pub fn update(self: *Gameplay) ?@import("popup.zig").PopupType {
        self.map.update();
        if (!self.map.alive()) return .over;
        if (self.map.hasClear()) return .clear;

        const speed = engine.frameTime() * playerSpeed;
        if (self.map.player1().alive) self.controlPlayer1(speed);
        if (self.mode and self.map.player2().alive) self.controlPlayer2(speed);

        return null;
    }

    fn controlPlayer1(self: *Gameplay, speed: usize) void {
        if (engine.isDown(engine.Key.a))
            self.map.control(self.map.player1(), speed, .west);
        if (engine.isDown(engine.Key.d))
            self.map.control(self.map.player1(), speed, .east);
        if (engine.isDown(engine.Key.w))
            self.map.control(self.map.player1(), speed, .north);
        if (engine.isDown(engine.Key.s))
            self.map.control(self.map.player1(), speed, .south);

        if (engine.isPressed(engine.Key.space)) {
            self.map.setBomb(self.map.player1());
        }
    }

    fn controlPlayer2(self: *Gameplay, speed: usize) void {
        if (engine.isDown(engine.Key.j))
            self.map.control(self.map.player2(), speed, .west);
        if (engine.isDown(engine.Key.l))
            self.map.control(self.map.player2(), speed, .east);
        if (engine.isDown(engine.Key.i))
            self.map.control(self.map.player2(), speed, .north);
        if (engine.isDown(engine.Key.k))
            self.map.control(self.map.player2(), speed, .south);

        if (engine.isPressed(engine.Key.b)) {
            self.map.setBomb(self.map.player2());
        }
    }

    pub fn draw(self: Gameplay) void {
        self.map.draw();
    }

    pub fn deinit(self: *Gameplay) void {
        self.map.deinit();
    }
};
