const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

const cursor = @import("cursor.zig");
const Region = @import("Region.zig");

var regions: [15]Region = undefined;
var returnTimer: ?window.Timer = null;
pub var returnPosition: math.Vector = .zero;
pub var pickedRegion: *Region = undefined;
pub var pickedMeal: ?cursor.Meal = undefined;
var position: math.Vector = .zero;
var velocity: math.Vector = .zero;

pub fn init() void {
    window.showCursor(false);

    regions[0] = .init(385, 142, .deliver);
    regions[1] = .init(690, 142, .deliver);
    regions[2] = .init(995, 142, .deliver);

    regions[3] = .init(300, 390, .cola);
    regions[4] = .init(425, 390, .sprite);
    regions[5] = .init(550, 418, .takeoutBoxBundle);

    regions[6] = .init(225, 520, .meatBallBox);
    regions[7] = .init(395, 520, .braisedChickenBox);
    regions[8] = .init(565, 520, .redCookedPorkBox);

    regions[9] = .init(740, 400, .microWave);
    regions[10] = .init(975, 400, .microWave);

    regions[11] = .init(830, 560, .takeoutBox);
    regions[12] = .init(935, 560, .takeoutBox);
    regions[13] = .init(1040, 560, .takeoutBox);
    regions[14] = .init(1145, 560, .takeoutBox);

    audio.playMusic("assets/bgm.ogg");
}

pub fn event(ev: *const window.Event) void {
    cursor.event(ev);
}

pub fn update(delta: f32) void {
    if (returnTimer) |*timer| {
        if (timer.isRunningAfterUpdate(delta)) {
            position = position.add(velocity.scale(delta));
        } else {
            returnTimer = null;
            pickedRegion.meal = pickedMeal;
            pickedMeal = null;
        }
        return;
    }

    for (&regions) |*region| {
        if (region.timer) |*timer| if (timer.isFinishedAfterUpdate(delta)) {
            region.timerFinished();
        };

        if (region.type == .deliver) region.updateDeliver(delta);

        if (cursor.picked == null and cursor.leftKeyDown) {
            if (region.area.contains(cursor.position)) region.pick();
        }

        if (cursor.picked != null and !cursor.leftKeyDown) {
            if (region.area.contains(cursor.position)) region.place();
        }
    }

    if (cursor.picked != null and !cursor.leftKeyDown) returnMeal();
}

fn returnMeal() void {
    cursor.picked = null;
    returnTimer = .init(0.5);
    position = cursor.position;
    velocity = returnPosition.sub(position).scale(1 / returnTimer.?.duration);
}

pub fn render() void {
    gfx.beginDraw();
    defer gfx.endDraw();

    gfx.draw(gfx.loadTexture("assets/background.png"), .zero);

    for (&regions) |*value| {
        if (value.texture) |texture| gfx.draw(texture, value.area.min);

        if (value.type == .takeoutBox) {
            if (value.meal) |meal|
                gfx.draw(meal.place, value.area.min.add(.{ .y = 20 }));
        }

        if (value.type == .microWave and value.timer == null) {
            if (value.meal) |meal|
                gfx.draw(meal.place, value.area.min.add(.{ .x = 113, .y = 65 }));
        }

        if (value.type == .deliver) value.renderDeliver();
    }

    if (returnTimer != null) {
        if (pickedMeal) |meal| gfx.draw(meal.picked, position);
    }

    cursor.render();
}

pub fn deinit() void {
    window.showCursor(true);
    audio.stopMusic();
}
