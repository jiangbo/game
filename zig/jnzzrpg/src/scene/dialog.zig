const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const camera = @import("../camera.zig");

const map = @import("map.zig");

pub var active: bool = false;

var index: u8 = 0;
pub var background: gfx.Texture = undefined;
pub var face: gfx.Texture = undefined;
pub var left: bool = true;
pub var npc: *map.NPC = undefined;
pub var name: []const u8 = &.{};
pub var content: []const u8 = &.{};

pub fn init() void {
    background = gfx.loadTexture("assets/msg.png", .init(790, 163));
    face = gfx.loadTexture("assets/face1_1.png", .init(307, 355));
}

pub fn show(mapNpc: *map.NPC) void {
    npc = mapNpc;
    active = true;
    index = 0;
    face = face;
    left = true;
    name = "主角";
    content =
        \\夏山如碧，绿树成荫，总会令人怡然自乐。
        \\此地山清水秀，我十分喜爱。我们便约好了，
        \\闲暇时，便来此地，彻茶共饮。
    ;
}

pub fn update(_: f32) void {
    index += 1;
    if (index == 1) {
        left = false;
        name = "女孩";
        content =
            \\嗯，说好了，一言为定。可是怎么感觉你
            \\这句话是山塞自哪里的。
        ;
    } else if (index == 2) {
        left = true;
        name = "主角";
        content =
            \\（被发现了TAT）
        ;
    } else active = false;
}

pub fn render() void {
    camera.draw(background, .init(0, 415));
    if (left) {
        camera.draw(face, .init(0, 245));
        camera.drawTextOptions(.{
            .text = name,
            .position = .init(255, 440),
            .color = .{ .r = 0.7, .g = 0.5, .b = 0.3, .a = 1 },
        });
        camera.drawText(content, .init(305, 455));
    } else {
        camera.draw(npc.face.?, .init(486, 245));
        camera.drawTextOptions(.{
            .text = name,
            .position = .init(160, 440),
            .color = .{ .r = 0.7, .g = 0.5, .b = 0.3, .a = 1 },
        });
        camera.drawText(content, .init(210, 455));
    }
}
