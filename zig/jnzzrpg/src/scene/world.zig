const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const camera = @import("../camera.zig");

pub const Player = @import("Player.zig");
pub const map = @import("map.zig");
const dialog = @import("dialog.zig");
const statusPopup = @import("statusPopup.zig");
const scene = @import("../scene.zig");
const bag = @import("bag.zig");
const shop = @import("shop.zig");

const Tip = struct {
    var background: gfx.Texture = undefined;
    content: []const u8,
};

pub var players: [3]Player = undefined;
pub var currentPlayer: *Player = &players[0];

var tip: ?Tip = null;
var talkTexture: gfx.Texture = undefined;

pub var mouseTarget: ?gfx.Vector = null;
var targetTexture: gfx.Texture = undefined;
var moveTimer: window.Timer = .init(0.4);
var moveDisplay: bool = true;

pub fn init() void {
    bag.init();

    players[0] = Player.init(0);
    players[1] = Player.init(1);
    players[2] = Player.init(2);

    Tip.background = gfx.loadTexture("assets/msgtip.png", .init(291, 42));
    targetTexture = gfx.loadTexture("assets/move_flag.png", .init(33, 37));
    talkTexture = gfx.loadTexture("assets/mc_2.png", .init(30, 30));

    statusPopup.init();
    shop.init();
    dialog.init();
    map.init();
}

pub fn enter() void {
    window.playMusic("assets/1.ogg");
}

pub fn exit() void {
    window.stopMusic();
    camera.lookAt(.zero);
}

pub fn update(delta: f32) void {
    const confirm = window.isAnyKeyRelease(&.{ .SPACE, .ENTER }) or
        window.isButtonRelease(.LEFT);

    if (dialog.active) return if (confirm) dialog.update(delta);
    if (shop.active) return shop.update(delta);

    if (tip) |_| {
        if (confirm) tip = null;
        return;
    }

    if (statusPopup.display) return statusPopup.update(delta);

    if (!statusPopup.display and (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }))) {
        statusPopup.display = true;
    }

    if (window.isButtonRelease(.LEFT)) {
        mouseTarget = camera.toWorldPosition(window.mousePosition);
    }

    if (mouseTarget != null) {
        if (moveTimer.isFinishedAfterUpdate(delta)) {
            moveDisplay = !moveDisplay;
            moveTimer.reset();
        }
    }

    currentPlayer.update(delta);

    for (map.npcSlice()) |*npc| {
        const contains = npc.area.contains(Player.position);
        if (contains) {
            if (npc.keyTrigger) {
                if (window.isAnyKeyRelease(&.{ .SPACE, .ENTER }))
                    npc.action();
            } else npc.action();
        }

        if (npc.texture != null) {
            const area = npc.area.move(camera.rect.min.neg());
            if (area.contains(window.mousePosition)) {
                scene.cursor = talkTexture;
                if (window.isButtonRelease(.LEFT) and contains) {
                    npc.action();
                }
            }
        }
        map.updateNpc(npc, delta);
    }
}

pub fn render() void {
    map.drawBackground();

    var playerNotDraw: bool = true;
    for (map.npcSlice()) |npc| {
        if (npc.position.y > Player.position.y and playerNotDraw) {
            currentPlayer.render();
            playerNotDraw = false;
        }

        const npcPosition = npc.position.sub(.init(120, 220));

        if (npc.animation != null and !npc.animation.?.finished()) {
            camera.draw(npc.animation.?.currentTexture(), npcPosition);
        } else if (npc.texture) |texture| {
            camera.draw(texture, npcPosition);
        }
    }

    if (playerNotDraw) currentPlayer.render();

    if (mouseTarget) |target| blk: {
        if (!moveDisplay) break :blk;
        const size = targetTexture.size();
        camera.draw(targetTexture, target.sub(.init(size.x / 2, size.y)));
    }

    map.drawForeground();
    renderPopup();

    window.showFrameRate();
}

fn renderPopup() void {
    camera.lookAt(.zero);

    if (dialog.active) dialog.render();
    if (shop.active) shop.render();

    if (tip) |t| {
        camera.draw(Tip.background, .init(251, 200));
        camera.drawText(t.content, .init(340, 207));
    }
    statusPopup.render();
    camera.lookAt(Player.position);
}

pub fn showDialog(npc: *map.NPC) void {
    dialog.show(npc);
}

pub fn openShop() void {
    shop.active = true;
}

pub fn showTip() void {
    tip = Tip{ .content = "遇到一个人" };
}
