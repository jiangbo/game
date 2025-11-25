const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;
const gfx = zhu.gfx;

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

    const playerView = ecs.w.getIdentity(Player, ViewField).?[0];
    for (map.spawns[1..]) |pos| {
        const entity = ecs.w.createEntity();
        if (playerView.contains(pos)) ecs.w.add(entity, PlayerView{});

        const index = zhu.random().weightedIndex(u8, &frequencies);
        const template = &templates[index];
        ecs.w.add(entity, pos);
        ecs.w.add(entity, map.worldPosition(pos));
        ecs.w.add(entity, map.getTextureFromTile(template.tile));
        ecs.w.add(entity, Name{template.name});

        switch (templates[index].entityType) {
            .item => spawnItem(entity, template),
            .enemy => spawnMonster(entity, template),
        }
    }
}

fn spawnItem(entity: ecs.Entity, t: *const Template) void {
    ecs.w.add(entity, Item{});
    if (t.tile == .map) return;
    if (t.damage == 0) {
        return ecs.w.add(entity, Healing{ .v = t.value });
    }
    ecs.w.add(entity, Damage{ .v = t.damage });
}

fn spawnMonster(enemy: ecs.Entity, t: *const Template) void {
    const hp: i32 = @intCast(t.value);
    ecs.w.add(enemy, Health{ .current = hp, .max = hp });
    ecs.w.add(enemy, ChasePlayer{});
    ecs.w.add(enemy, Enemy{});
    ecs.w.add(enemy, Damage{ .v = t.damage });
}

pub fn update() void {
    ecs.w.addContext(TurnState.player);

    moveOrAttack();
    battle.attack();
    map.moveIfNeed();
}

fn moveOrAttack() void {
    const playerEntity = ecs.w.getIdentityEntity(Player).?;
    const playerPos = ecs.w.get(playerEntity, TilePosition);
    const rect = ecs.w.get(playerEntity, ViewField)[0];

    var view = ecs.w.view(.{ ChasePlayer, TilePosition });
    while (view.next()) |entity| {
        var pos = view.get(entity, TilePosition);
        if (rect.contains(pos)) view.add(entity, PlayerView{});
        const enemyRect: TileRect = .fromCenter(pos, viewSize);
        if (!enemyRect.contains(playerPos)) continue;

        const next = map.queryLessDistance(pos) orelse continue;

        if (playerPos.equals(next)) {
            view.add(entity, WantToAttack{playerEntity});
            continue;
        }

        for (ecs.w.raw(TilePosition)) |tilePos| {
            if (!tilePos.equals(next)) continue;

            const step = zhu.math.randomStep(u8, 1);
            if (pos.x == next.x) pos.x +%= step else pos.y +%= step;
            view.add(entity, WantToMove{pos});
            break;
        } else view.add(entity, WantToMove{next});
    }
}
