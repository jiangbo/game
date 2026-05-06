const zhu = @import("zhu");

const ctx = @import("context.zig");
const map = @import("map.zig");
const spawn = @import("spawn.zig");

var titleLogo: zhu.graphics.Image = undefined;

pub fn init() void {
    titleLogo = zhu.getImage("textures/UI/title.png");
}
pub fn deinit() void {
    map.deinit();
}

pub fn enter() void {
    ctx.timeScale = 1;
    map.init(0);
    zhu.audio.playMusic("assets/audio/HEROICCC(chosic.com).ogg");
}

pub fn startGame() void {
    if (ctx.levelClear) {
        ctx.levelClear = false;
        if (!spawn.hasNextLevel(ctx.levelIndex)) {
            ctx.win = true;
            ctx.pendingScene = .end;
        } else {
            ctx.levelIndex += 1;
            ctx.pendingScene = .battle;
        }
    } else {
        ctx.pendingScene = .battle;
    }
}

pub fn exit() void {
    map.deinit();
}

pub fn update(delta: f32) void {
    map.update(delta);
}

pub fn draw() void {
    map.draw();
    zhu.batch.drawImage(titleLogo, .xy(338.667, 272.0), .{
        .size = .xy(866.667, 609.333),
    });
}
