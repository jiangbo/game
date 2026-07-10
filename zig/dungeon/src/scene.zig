const std = @import("std");
const zhu = @import("zhu");

const ecs = @import("ecs");
const game = @import("world.zig");

const map = @import("map.zig");
const player = @import("player.zig");
const monster = @import("monster.zig");
const hud = @import("hud.zig");
const battle = @import("battle.zig");
const component = @import("component.zig");
const item = @import("item.zig");

const Player = component.Player;
const Position = component.Position;
const TilePosition = component.TilePosition;
const WantToMove = component.WantToMove;
const TurnState = component.TurnState;
const PlayerView = component.PlayerView;

var isHelp = false;
var isDebug = false;

pub fn init(allocator: zhu.Allocator) void {
    zhu.text.init(@import("zon/font.zon"));
    zhu.text.changeFontSize(16);
    game.init(allocator.raw);

    restart();
}

fn restart() void {
    game.reset();
    initWorld(1);
}

fn initWorld(mapLevel: u8) void {
    game.turn = .player;
    hud.init();
    map.init(mapLevel);
    player.init();
    item.init();
    monster.init();
}

fn nextLevel() void {
    var nextWorld = ecs.World.init(game.world.allocator);
    // 保留拾取的物品
    var query = game.world.query(.{ component.Carried, component.Name });
    while (query.next()) |entity| {
        const newEntity = nextWorld.createEntity();
        nextWorld.add(newEntity, component.Carried{});
        nextWorld.add(newEntity, component.Item{});
        nextWorld.add(newEntity, component.PlayerView{});
        if (game.world.get(entity, component.Healing)) |heal| {
            nextWorld.add(newEntity, heal);
        }
        if (game.world.get(entity, component.Damage)) |damage| {
            nextWorld.add(newEntity, damage);
        }
        nextWorld.add(newEntity, query.get(entity, component.Name));
    }
    // 保留角色攻击力
    const damage = game.world.get(player.entity, component.Damage).?;
    const health = game.world.get(player.entity, component.Health).?;

    game.world.deinit();
    game.world = nextWorld;
    // 保留地图等级
    initWorld(map.currentLevel + 1);
    game.world.add(player.entity, damage);
    game.world.add(player.entity, health);
}

pub fn update(_: f32) void {
    if (zhu.key.released(.H)) isHelp = !isHelp;
    if (zhu.key.released(.X)) isDebug = !isDebug;

    if (zhu.key.held(.LEFT_ALT) and zhu.key.released(.ENTER)) {
        return zhu.window.toggleFullScreen();
    }

    if (zhu.key.released(.M)) map.minMap = !map.minMap;

    switch (game.turn) {
        .over, .win => if (zhu.key.released(._1)) restart(),
        .player => player.update(),
        .monster => monster.update(),
        .next => nextLevel(),
    }
}

pub fn draw() void {
    sceneCall("draw", .{});

    if (map.minMap) zhu.camera.push(.windowScale(.zero, .square(0.25)));
    defer if (map.minMap) zhu.camera.pop();

    map.draw();

    var query = game.world.query(.{ zhu.Image, Position, PlayerView });
    while (query.next()) |entity| {
        const pos = query.get(entity, Position);
        const image = query.get(entity, zhu.Image);
        zhu.batch.drawImage(image, pos, .{});
    }

    hud.draw();

    if (isHelp) drawHelpInfo() else if (isDebug) drawDebugInfo();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关掉
    ;
    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    zhu.text.draw(text, .xy(10, 5), .{ .color = .green });
}

var debutTextCount: u32 = 0;
fn drawDebugInfo() void {
    zhu.debug.draw(&.{});
}

pub fn deinit() void {
    sceneCall("deinit", .{});
    game.deinit();
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    _ = function;
    _ = args;
}
