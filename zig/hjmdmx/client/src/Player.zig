const std = @import("std");
const math = @import("math.zig");
const gfx = @import("graphics.zig");

const FourAnimation = struct {
    up: gfx.SliceFrameAnimation,
    down: gfx.SliceFrameAnimation,
    left: gfx.SliceFrameAnimation,
    right: gfx.SliceFrameAnimation,
};

const SPEED_RUN = 100;

index: i32,
position: math.Vector = .zero,
velocity: math.Vector = .zero,
idle: FourAnimation,
run: FourAnimation,
keydown: ?math.FourDirection = null,
current: math.FourDirection = .right,

pub fn init(index: i32) @This() {
    if (index == 1) return .{
        .index = index,
        .idle = .{
            .up = .load("assets/hajimi_idle_back_{}.png", 4),
            .down = .load("assets/hajimi_idle_front_{}.png", 4),
            .left = .load("assets/hajimi_idle_left_{}.png", 4),
            .right = .load("assets/hajimi_idle_right_{}.png", 4),
        },

        .run = .{
            .up = .load("assets/hajimi_run_back_{}.png", 4),
            .down = .load("assets/hajimi_run_front_{}.png", 4),
            .left = .load("assets/hajimi_run_left_{}.png", 4),
            .right = .load("assets/hajimi_run_right_{}.png", 4),
        },
    };

    return .{
        .index = index,
        .idle = .{
            .up = .load("assets/manbo_idle_back_{}.png", 4),
            .down = .load("assets/manbo_idle_front_{}.png", 4),
            .left = .load("assets/manbo_idle_left_{}.png", 4),
            .right = .load("assets/manbo_idle_right_{}.png", 4),
        },

        .run = .{
            .up = .load("assets/manbo_run_back_{}.png", 4),
            .down = .load("assets/manbo_run_front_{}.png", 4),
            .left = .load("assets/manbo_run_left_{}.png", 4),
            .right = .load("assets/manbo_run_right_{}.png", 4),
        },
    };
}

pub fn currentAnimation(player: *@This()) *gfx.SliceFrameAnimation {
    var animation = if (player.keydown == null) &player.idle else &player.run;

    return switch (player.current) {
        .up => &animation.up,
        .down => &animation.down,
        .left => &animation.left,
        .right => &animation.right,
    };
}

pub fn anchorCenter(player: *@This()) void {
    anchor(&player.idle);
    anchor(&player.run);
}

fn anchor(animation: *FourAnimation) void {
    animation.up.anchorCenter();
    animation.down.anchorCenter();
    animation.left.anchorCenter();
    animation.right.anchorCenter();
}
