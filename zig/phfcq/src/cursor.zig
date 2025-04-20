const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

pub const MealType = enum {
    cola,
    sprite,
    braisedChickenHot,
    braisedChickenCold,
    meatBallHot,
    meatBallCold,
    redCookedPorkHot,
    redCookedPorkCold,
    braisedChickenBox,
    meatBallBox,
    redCookedPorkBox,
    takeoutBox,
};

pub const Meal = struct {
    type: MealType,
    picked: gfx.Texture = undefined,
    place: gfx.Texture = undefined,
    icon: gfx.Texture = undefined,
    done: bool = false,

    pub fn init(mealType: MealType) Meal {
        var self: Meal = Meal{ .type = mealType };

        switch (mealType) {
            .cola => {
                self.picked = gfx.loadTexture("assets/cola.png");
                self.place = gfx.loadTexture("assets/cola.png");
                self.icon = gfx.loadTexture("assets/cola_icon.png");
            },
            .sprite => {
                self.picked = gfx.loadTexture("assets/sprite.png");
                self.place = gfx.loadTexture("assets/sprite.png");
                self.icon = gfx.loadTexture("assets/sprite_icon.png");
            },
            .braisedChickenHot => {
                self.picked = gfx.loadTexture("assets/bc_hot_picked.png");
                self.place = gfx.loadTexture("assets/bc_hot.png");
                self.icon = gfx.loadTexture("assets/bc_icon.png");
            },
            .braisedChickenCold => {
                self.picked = gfx.loadTexture("assets/bc_cold_picked.png");
                self.place = gfx.loadTexture("assets/bc_cold.png");
            },
            .meatBallHot => {
                self.picked = gfx.loadTexture("assets/mb_hot_picked.png");
                self.place = gfx.loadTexture("assets/mb_hot.png");
                self.icon = gfx.loadTexture("assets/mb_icon.png");
            },
            .meatBallCold => {
                self.picked = gfx.loadTexture("assets/mb_cold_picked.png");
                self.place = gfx.loadTexture("assets/mb_cold.png");
            },
            .redCookedPorkHot => {
                self.picked = gfx.loadTexture("assets/rcp_hot_picked.png");
                self.place = gfx.loadTexture("assets/rcp_hot.png");
                self.icon = gfx.loadTexture("assets/rcp_icon.png");
            },
            .redCookedPorkCold => {
                self.picked = gfx.loadTexture("assets/rcp_cold_picked.png");
                self.place = gfx.loadTexture("assets/rcp_cold.png");
            },

            .braisedChickenBox => {
                self.picked = gfx.loadTexture("assets/bc_box.png");
                self.place = gfx.loadTexture("assets/bc_box.png");
            },
            .meatBallBox => {
                self.picked = gfx.loadTexture("assets/mb_box.png");
                self.place = gfx.loadTexture("assets/mb_box.png");
            },
            .redCookedPorkBox => {
                self.picked = gfx.loadTexture("assets/rcp_box.png");
                self.place = gfx.loadTexture("assets/rcp_box.png");
            },
            .takeoutBox => {
                self.picked = gfx.loadTexture("assets/tb_picked.png");
                self.place = gfx.loadTexture("assets/tb.png");
            },
        }

        return self;
    }
};

pub var position: math.Vector = .zero;
pub var leftKeyDown: bool = false;
pub var picked: ?Meal = null;

pub fn event(ev: *const window.Event) void {
    if (ev.type == .MOUSE_MOVE) {
        position = .init(ev.mouse_x, ev.mouse_y);
    }

    if (ev.mouse_button == .LEFT) {
        if (ev.type == .MOUSE_DOWN) {
            leftKeyDown = true;
            switch (math.randU8(1, 3)) {
                1 => audio.playSound("assets/click_1.ogg"),
                2 => audio.playSound("assets/click_2.ogg"),
                3 => audio.playSound("assets/click_3.ogg"),
                else => unreachable,
            }
        }
        if (ev.type == .MOUSE_UP) leftKeyDown = false;
    }
}

pub fn render() void {
    if (picked) |meal| {
        gfx.draw(meal.picked, position.sub(meal.picked.size().scale(0.3)));
    }

    if (leftKeyDown) {
        gfx.draw(gfx.loadTexture("assets/cursor_down.png"), position);
    } else {
        gfx.draw(gfx.loadTexture("assets/cursor_idle.png"), position);
    }
}
