const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;
const ecs = zhu.ecs;

const map = @import("map.zig");
const component = @import("component.zig");

const Player = component.Player;
const Health = component.Health;
const Name = component.Name;
const Position = component.Position;
const TurnState = component.TurnState;
const PlayerView = component.PlayerView;
const Item = component.Item;
const Carried = component.Carried;

const TILE_SIZE = 32;

var texture: gfx.Texture = undefined;
const healthForeground: math.Vector4 = .init(0.298, 0.735, 0.314, 1);
const healthBackground: math.Vector4 = .init(0.2, 0.2, 0.2, 1);

pub fn init() void {
    texture = gfx.loadTexture("assets/terminal8x8.png", .init(128, 128));
    camera.whiteTexture = texture.subTexture(.init(.init(88, 104), size));
}

pub fn draw() void {
    camera.mode = .local;
    defer camera.mode = .world;

    var pos: gfx.Vector = .init(window.logicSize.x / 2, 10);
    var healthSize: gfx.Vector = .init(200, 12);
    const healthPos = pos.sub(healthSize.scale(0.5));

    const health = ecs.w.getIdentity(Player, Health).?;
    var buffer: [50]u8 = undefined;
    var text = zhu.format(&buffer, "Health: {} / {}", //
        .{ health.current, health.max });

    camera.drawRect(.init(healthPos, healthSize), healthBackground);
    healthSize.x *= math.percentInt(health.current, health.max);
    camera.drawRect(.init(healthPos, healthSize), healthForeground);

    drawTextCenter(text, pos, .{});
    pos.y += size.x * 2;
    drawTextCenter("Explore the Dungeon. A/S/D/W to move.", pos, .{});

    const damage = ecs.w.getIdentity(Player, component.Damage).?.v;
    const fmt = "Damage: {} Dungeon Level: {}";
    text = zhu.format(&buffer, fmt, .{ damage, map.currentLevel });
    const textSize = size.mul(.init(@floatFromInt(text.len), 1));
    const x = window.logicSize.x - textSize.x - 5;
    drawText(text, .init(x, 10), .{});

    if (!map.minMap) drawNameAndHealthIfNeed();
    drawCarriedItemIfNeed();
    drawGameOverIfNeed();
    drawGameWinIfNeed();
}

fn drawNameAndHealthIfNeed() void {
    var buffer: [50]u8 = undefined;

    var view = ecs.w.view(.{ Name, Position, PlayerView });
    while (view.next()) |entity| {
        var position = view.get(entity, Position);
        const name = view.get(entity, Name)[0];

        position = position.addXY(TILE_SIZE / 2, -size.y);
        var text: []const u8 = undefined;
        if (view.tryGet(entity, Health)) |h| {
            text = zhu.format(&buffer, "{s}: {}hp", .{ name, h.current });
        } else {
            text = zhu.format(&buffer, "{s}", .{name});
        }
        drawTextCenter(text, camera.toWindow(position), .{});
    }
}

fn drawCarriedItemIfNeed() void {
    var view = ecs.w.viewOption(.{ Carried, Item, Name }, .{}, .{
        .useFirst = true,
    });
    var index: u8 = 1;
    var buffer: [44]u8 = undefined;
    while (view.next()) |entity| : (index += 1) {
        if (index > 9) break;
        const name = view.get(entity, Name)[0];
        const offset: f32 = @floatFromInt(index * 16);
        const pos = gfx.Vector.init(30, 20 + offset);
        const text = zhu.format(&buffer, "{}: {s}", .{ index, name });
        drawText(text, pos, .{});
    }
    if (index == 1) return;

    const pos = gfx.Vector.init(15, 15);
    drawText("Items carried", pos, .{ .color = .yellow });
    const offset: f32 = @floatFromInt(index * 16 + 15);
    drawText("Number to use", pos.addY(offset), .{ .color = .yellow });
}

fn drawGameOverIfNeed() void {
    if (ecs.w.getContext(TurnState).? != .over) return;

    var pos: gfx.Vector = .init(window.logicSize.x / 2, 130);
    var text: []const u8 = "Your quest has ended.";
    drawTextCenter(text, pos, .{ .color = .red, .scale = 2 });

    text = "Slain by a monster, your hero's journey has come to a end.";
    pos = pos.addY(50);
    drawTextCenter(text, pos, .{});
    text = "The Amulet of Yala remains unclaimed," ++
        " and your home town is not saved.";
    pos = pos.addY(20);
    drawTextCenter(text, pos, .{});

    text = "Don't worry, you can always try again with a new hero.";
    pos = pos.addY(40);
    drawTextCenter(text, pos, .{ .color = .yellow });

    text = "Press 1 to play again.";
    pos = pos.addY(50);
    drawTextCenter(text, pos, .{ .color = .green, .scale = 2 });
}

fn drawGameWinIfNeed() void {
    if (ecs.w.getContext(TurnState).? != .win) return;

    var pos: gfx.Vector = .init(window.logicSize.x / 2, 130);
    var text: []const u8 = "You have won!";
    drawTextCenter(text, pos, .{ .color = .green, .scale = 2 });

    text = "You put on the Amulet of Yala and feel its power " ++
        "course through your veins.";
    pos = pos.addY(50);
    drawTextCenter(text, pos, .{});
    text = "Your town is saved, and you can return to your normal life.";
    pos = pos.addY(20);
    drawTextCenter(text, pos, .{});

    text = "Press 1 to play again.";
    pos = pos.addY(50);
    drawTextCenter(text, pos, .{ .color = .green, .scale = 2 });
}

const Options = struct { color: gfx.Color = .white, scale: f32 = 1 };
fn drawTextCenter(text: []const u8, pos: Position, opt: Options) void {
    const textSize = size.mul(.init(@floatFromInt(text.len), 1));
    drawText(text, pos.sub(textSize.scale(0.5).scale(opt.scale)), opt);
}

const size: Position = .init(8, 8);
fn drawText(text: []const u8, position: Position, opt: Options) void {
    var pos = position;

    for (text) |byte| {
        const x: f32 = @floatFromInt(byte % 16);
        const y: f32 = @floatFromInt(byte / 16);
        const charTexture = texture.subTexture(.{
            .min = size.mul(.init(x, y)),
            .size = size,
        });

        camera.drawOption(charTexture, pos, .{
            .color = opt.color,
            .size = size.scale(opt.scale),
        });
        pos.x += size.x * opt.scale;
    }
}
