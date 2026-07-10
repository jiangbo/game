const std = @import("std");
const zhu = @import("zhu");

const ecs = @import("ecs");
const game = @import("world.zig");

const map = @import("map.zig");
const battle = @import("battle.zig");
const item = @import("item.zig");
const component = @import("component.zig");

const Player = component.Player;
const Enemy = component.Enemy;
const WantToAttack = component.WantToAttack;
const Health = component.Health;
const TurnState = component.TurnState;
const Position = component.Position;
const TilePosition = component.TilePosition;
const TileRect = component.TileRect;
const Amulet = component.Amulet;
const ViewField = component.ViewField;
const PlayerView = component.PlayerView;
const Item = component.Item;
const Carried = component.Carried;
const Healing = component.Healing;
const Damage = component.Damage;

pub var entity: ecs.Entity = undefined;
const viewSize = 4;

pub fn init() void {
    entity = game.world.createIdentity(Player);

    const tilePos = map.spawns[0];
    game.world.add(entity, tilePos);
    game.world.add(entity, map.getTextureFromTile(.player));
    game.world.add(entity, map.worldPosition(tilePos));
    const health: Health = .{ .max = 10, .current = 10 };
    game.world.add(entity, health);
    game.world.add(entity, ViewField{.fromCenter(tilePos, viewSize)});
    game.world.add(entity, PlayerView{});
    game.world.add(entity, Damage{ .v = 1 });
    map.updatePlayerWalk();

    cameraFollow(map.worldPosition(tilePos));
}

pub fn update() void {
    if (zhu.key.anyReleased(&.{ .ESCAPE, .Q })) {
        map.minMap = false;
    }

    const playerPos = game.world.get(entity, TilePosition).?;
    if (zhu.key.released(.G)) { // 拾取物品
        // 找到在角色视野中的物品，判断是否可以拾取
        var query = game.world.query(.{ Item, TilePosition, PlayerView });
        while (query.next()) |itemEntity| {
            const pos = query.get(itemEntity, TilePosition);
            if (!playerPos.equals(pos)) continue;
            // 找到一个物品可以拾取
            game.turn = .monster;
            game.world.remove(itemEntity, TilePosition);
            game.world.remove(itemEntity, Position);
            game.world.remove(itemEntity, zhu.Image);
            game.world.add(itemEntity, Carried{});
            return;
        }
    }

    const start: u32 = @intFromEnum(zhu.input.key.Code._0);
    var query = game.world.query(.{ Item, Carried });
    var index: u8 = 1;
    while (query.next()) |itemEntity| : (index += 1) {
        if (index > 9) break;
        if (!zhu.key.released(@enumFromInt(start + index))) continue;

        if (game.world.get(itemEntity, Healing)) |heal| { // 使用药水
            const h = game.world.getPtr(entity, Health).?;
            h.current = @min(h.max, h.current + heal.v);
        } else if (game.world.get(itemEntity, Damage)) |damage| {
            game.world.add(entity, damage);
        } else map.minMap = !map.minMap;

        game.world.remove(itemEntity, Carried);
        game.world.destroyEntity(itemEntity);
        game.turn = .monster;
        return;
    }

    var newPos = playerPos;
    if (zhu.key.released(.W)) newPos.y -|= 1 //
    else if (zhu.key.released(.S)) newPos.y += 1 //
    else if (zhu.key.released(.A)) newPos.x -|= 1 //
    else if (zhu.key.released(.D)) newPos.x += 1 //
    else return;

    if (playerPos.equals(newPos)) return; // 没有移动

    if (map.finalPos.equals(newPos)) {
        const final = map.currentLevel == map.MAX_LEVEL;
        const state: TurnState = if (final) .win else .next;
        game.turn = state;
    } else moveOrAttack(newPos);

    battle.attack();
}

fn moveOrAttack(newPos: TilePosition) void {
    game.turn = .monster;
    if (!map.canMove(newPos)) return; // 不能移动，撞墙也算移动

    var query = game.world.query(.{ Enemy, TilePosition });
    while (query.next()) |enemy| {
        const position = query.get(enemy, TilePosition);
        if (!newPos.equals(position)) continue;

        const enemyEntity = enemy;
        game.world.add(entity, WantToAttack{enemyEntity});
        return;
    }

    const viewField = ViewField{.fromCenter(newPos, viewSize)};
    game.world.add(entity, newPos);
    game.world.add(entity, viewField);
    game.world.add(entity, map.worldPosition(newPos));

    item.update();

    map.updatePlayerWalk();
    map.updateDistance(newPos);
    cameraFollow(map.worldPosition(newPos));
}

fn cameraFollow(position: Position) void {
    const scaleSize = zhu.window.size;
    const half = scaleSize.scale(0.5);
    const max = map.size.sub(scaleSize).max(.zero);
    zhu.camera.main.position = position.sub(half).clamp(.zero, max);
}
