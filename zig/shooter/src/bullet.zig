const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;

var texture: gfx.Texture = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/image/laser-1.png", .init(81, 126));
}

// pub fn update(delta: f32) void {}
