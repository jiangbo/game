const zhu = @import("zhu");

const game = @import("world.zig");
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

pub fn init() void {}

pub fn draw() void {
    zhu.camera.push(.window);
    defer zhu.camera.pop();

    var pos: zhu.Vector2 = .xy(zhu.window.size.x / 2, 10);
    var healthSize: zhu.Vector2 = .xy(200, 12);
    const healthPos = pos.sub(healthSize.scale(0.5));

    const health = game.world.get(game.world.getIdentity(Player).?, Health).?;
    var buffer: [50]u8 = undefined;
    var text = zhu.format(&buffer, "Health: {} / {}", .{
        health.current,
        health.max,
    });

    zhu.batch.drawRect(.init(healthPos, healthSize), .{
        .color = .rgba(0.2, 0.2, 0.2, 1),
    });
    healthSize.x *= zhu.math.percentInt(health.current, health.max);
    zhu.batch.drawRect(.init(healthPos, healthSize), .{
        .color = .rgba(0.298, 0.735, 0.314, 1),
    });

    drawTextCenter(text, pos, .{});
    pos.y += 16;
    drawTextCenter("Explore the Dungeon. A/S/D/W to move.", pos, .{});

    const damage = game.world.get(game.world.getIdentity(Player).?, component.Damage).?.v;
    text = zhu.format(&buffer, "Damage: {} Dungeon Level: {}", .{
        damage,
        map.currentLevel,
    });
    const textSize = zhu.text.measure(text, .{});
    drawText(text, .xy(zhu.window.size.x - textSize.x - 5, 10), .{});

    if (!map.minMap) drawNameAndHealthIfNeed();
    drawCarriedItemIfNeed();
    drawGameOverIfNeed();
    drawGameWinIfNeed();
}

fn drawNameAndHealthIfNeed() void {
    var buffer: [50]u8 = undefined;

    var query = game.world.query(.{ Name, Position, PlayerView });
    while (query.next()) |entity| {
        var position = query.get(entity, Position);
        const name = query.get(entity, Name)[0];

        position = position.addXY(16, -8);
        const text = if (game.world.get(entity, Health)) |h|
            zhu.format(&buffer, "{s}: {}hp", .{ name, h.current })
        else
            zhu.format(&buffer, "{s}", .{name});
        drawTextCenter(text, zhu.camera.toWindow(position), .{});
    }
}

fn drawCarriedItemIfNeed() void {
    var query = game.world.query(.{ Carried, Item, Name });
    var index: u8 = 1;
    var buffer: [44]u8 = undefined;
    while (query.next()) |entity| : (index += 1) {
        if (index > 9) break;
        const name = query.get(entity, Name)[0];
        const offset: f32 = @floatFromInt(index * 16);
        const text = zhu.format(&buffer, "{}: {s}", .{ index, name });
        drawText(text, .xy(30, 20 + offset), .{});
    }
    if (index == 1) return;

    drawText("Items carried", .xy(15, 15), .{ .color = .yellow });
    const offset: f32 = @floatFromInt(index * 16 + 15);
    drawText("Number to use", .xy(15, 15 + offset), .{ .color = .yellow });
}

fn drawGameOverIfNeed() void {
    if (game.turn != .over) return;

    var pos: zhu.Vector2 = .xy(zhu.window.size.x / 2, 130);
    drawTextCenter("Your quest has ended.", pos, .{ .color = .red, .scale = 2 });

    pos = pos.addY(50);
    drawTextCenter(
        "Slain by a monster, your hero's journey has come to a end.",
        pos,
        .{},
    );
    pos = pos.addY(20);
    drawTextCenter(
        "The Amulet of Yala remains unclaimed, and your home town is not saved.",
        pos,
        .{},
    );

    pos = pos.addY(40);
    drawTextCenter(
        "Don't worry, you can always try again with a new hero.",
        pos,
        .{ .color = .yellow },
    );

    pos = pos.addY(50);
    drawTextCenter("Press 1 to play again.", pos, .{
        .color = .green,
        .scale = 2,
    });
}

fn drawGameWinIfNeed() void {
    if (game.turn != .win) return;

    var pos: zhu.Vector2 = .xy(zhu.window.size.x / 2, 130);
    drawTextCenter("You have won!", pos, .{ .color = .green, .scale = 2 });

    pos = pos.addY(50);
    drawTextCenter(
        "You put on the Amulet of Yala and feel its power course through your veins.",
        pos,
        .{},
    );
    pos = pos.addY(20);
    drawTextCenter(
        "Your town is saved, and you can return to your normal life.",
        pos,
        .{},
    );

    pos = pos.addY(50);
    drawTextCenter("Press 1 to play again.", pos, .{
        .color = .green,
        .scale = 2,
    });
}

const Options = struct { color: zhu.Color = .white, scale: f32 = 1 };
fn drawTextCenter(text: []const u8, pos: zhu.Vector2, opt: Options) void {
    const option = textOption(opt);
    const textSize = zhu.text.measure(text, option);
    drawText(text, pos.sub(textSize.scale(0.5)), opt);
}

fn drawText(text: []const u8, position: zhu.Vector2, opt: Options) void {
    zhu.text.draw(text, position, textOption(opt));
}

fn textOption(opt: Options) zhu.text.Option {
    return .{ .color = opt.color, .scale = .square(opt.scale) };
}
