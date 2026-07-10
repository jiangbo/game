const std = @import("std");
const zhu = @import("zhu");

const ecs = @import("ecs");
const game = @import("world.zig");

const map = @import("map.zig");
const battle = @import("battle.zig");
const component = @import("component.zig");

const Player = component.Player;
const Enemy = component.Enemy;
const Health = component.Health;
const Name = component.Name;
const TileRect = component.TileRect;
const TurnState = component.TurnState;
const TilePosition = component.TilePosition;
const WantToMove = component.WantToMove;
const WantToAttack = component.WantToAttack;
const ChasePlayer = component.ChasePlayer;
const PlayerView = component.PlayerView;
const ViewField = component.ViewField;
const Tile = component.Tile;
const Item = component.Item;
const Healing = component.Healing;
const Damage = component.Damage;

const MovingRandomly = struct {};
const viewSize = 3;

const Template = struct {
    entityType: enum { enemy, item },
    levels: []const u8,
    frequency: u8,
    damage: u8 = 0,
    name: []const u8,
    tile: Tile,
    value: u8 = 0,
};
const templates: []const Template = @import("zon/templates.zon");
var frequencies: [templates.len]u8 = undefined;

pub fn init() void {
    for (templates, &frequencies) |template, *f| {
        const contains = std.mem.indexOfScalar;
        const found = contains(u8, template.levels, map.currentLevel);
        f.* = if (found == null) 0 else template.frequency;
    }

    const player = game.world.getIdentity(Player).?;
    const playerView = game.world.get(player, ViewField).?[0];
    for (map.spawns[1..]) |pos| {
        const entity = game.world.createEntity();
        if (playerView.contains(pos)) game.world.add(entity, PlayerView{});

        const index = zhu.random.int(u8, 0, frequencies.len);
        const template = &templates[index];
        game.world.add(entity, pos);
        game.world.add(entity, map.worldPosition(pos));
        game.world.add(entity, map.getTextureFromTile(template.tile));
        game.world.add(entity, Name{template.name});

        switch (templates[index].entityType) {
            .item => spawnItem(entity, template),
            .enemy => spawnMonster(entity, template),
        }
    }
}

fn spawnItem(entity: ecs.Entity, t: *const Template) void {
    game.world.add(entity, Item{});
    if (t.tile == .map) return;
    if (t.damage == 0) {
        return game.world.add(entity, Healing{ .v = t.value });
    }
    game.world.add(entity, Damage{ .v = t.damage });
}

fn spawnMonster(enemy: ecs.Entity, t: *const Template) void {
    const hp: i32 = @intCast(t.value);
    game.world.add(enemy, Health{ .current = hp, .max = hp });
    game.world.add(enemy, ChasePlayer{});
    game.world.add(enemy, Enemy{});
    game.world.add(enemy, Damage{ .v = t.damage });
}

pub fn update() void {
    game.turn = .player;

    moveOrAttack();
    battle.attack();
    map.moveIfNeed();
}

fn moveOrAttack() void {
    const playerEntity = game.world.getIdentity(Player).?;
    const playerPos = game.world.get(playerEntity, TilePosition).?;
    const rect = game.world.get(playerEntity, ViewField).?[0];

    var query = game.world.query(.{ ChasePlayer, TilePosition });
    while (query.next()) |entity| {
        var pos = query.get(entity, TilePosition);
        if (rect.contains(pos)) game.world.add(entity, PlayerView{});
        const enemyRect: TileRect = .fromCenter(pos, viewSize);
        if (!enemyRect.contains(playerPos)) continue;

        const next = map.queryLessDistance(pos) orelse continue;

        if (playerPos.equals(next)) {
            game.world.add(entity, WantToAttack{playerEntity});
            continue;
        }

        for (game.world.values(TilePosition)) |tilePos| {
            if (!tilePos.equals(next)) continue;

            const step = zhu.random.int(u8, 0, 2) * 2 -% 1;
            if (pos.x == next.x) pos.x +%= step else pos.y +%= step;
            game.world.add(entity, WantToMove{pos});
            break;
        } else game.world.add(entity, WantToMove{next});
    }
}
