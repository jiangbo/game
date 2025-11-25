const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const ecs = zhu.ecs;

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
    const amulet = ecs.w.createIdentityEntity(Amulet);

    const pos = map.finalPos;
    ecs.w.add(amulet, pos);
    const texture = map.getTextureFromTile(.amulet);
    ecs.w.alignAdd(amulet, .{ map.worldPosition(pos), texture });
    ecs.w.add(amulet, Item{});
}

fn spawnExit() void {
    const exit = ecs.w.createEntity();

    const pos = map.finalPos;
    ecs.w.add(exit, pos);
    const texture = map.getTextureFromTile(.exit);
    ecs.w.alignAdd(exit, .{ map.worldPosition(pos), texture });
    ecs.w.add(exit, Item{});
}

pub fn update() void {
    const playerEntity = ecs.w.getIdentityEntity(Player).?;
    const viewField = ecs.w.get(playerEntity, ViewField)[0];

    var view = ecs.w.viewOption(.{Item}, .{PlayerView}, .{});
    while (view.next()) |item| {
        const itemPos = view.get(item, TilePosition);
        if (viewField.contains(itemPos)) {
            view.add(item, PlayerView{});
        }
    }
}
