const std = @import("std");
const zhu = @import("zhu");

const ecs = @import("ecs");
const game = @import("world.zig");

const map = @import("map.zig");
const component = @import("component.zig");

const TilePosition = component.TilePosition;
const Amulet = component.Amulet;
const Player = component.Player;
const PlayerView = component.PlayerView;
const ViewField = component.ViewField;
const Item = component.Item;

pub fn init() void {
    if (map.currentLevel == map.MAX_LEVEL) {
        spawnAmulet();
    } else {
        spawnExit();
    }
}

fn spawnAmulet() void {
    const amulet = game.world.createIdentity(Amulet);

    const pos = map.finalPos;
    game.world.add(amulet, pos);
    const texture = map.getTextureFromTile(.amulet);
    game.world.addAll(amulet, .{ map.worldPosition(pos), texture });
    game.world.add(amulet, Item{});
}

fn spawnExit() void {
    const exit = game.world.createEntity();

    const pos = map.finalPos;
    game.world.add(exit, pos);
    const texture = map.getTextureFromTile(.exit);
    game.world.addAll(exit, .{ map.worldPosition(pos), texture });
    game.world.add(exit, Item{});
}

pub fn update() void {
    const playerEntity = game.world.getIdentity(Player).?;
    const viewField = game.world.get(playerEntity, ViewField).?[0];

    var query = game.world.queryNot(.{ Item, TilePosition }, .{PlayerView});
    while (query.next()) |item| {
        const itemPos = query.get(item, TilePosition);
        if (viewField.contains(itemPos)) {
            game.world.add(item, PlayerView{});
        }
    }
}
