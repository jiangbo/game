const std = @import("std");
const zhu = @import("zhu");

const ecs = @import("ecs");
const game = @import("world.zig");

const component = @import("component.zig");

const Player = component.Player;
const Enemy = component.Enemy;
const WantToMove = component.WantToMove;
const TilePosition = component.TilePosition;
const WantToAttack = component.WantToAttack;
const Health = component.Health;
const TurnState = component.TurnState;

pub fn attack() void {
    var query = game.world.query(.{ WantToAttack, component.Damage });
    while (query.next()) |entity| {
        const target = query.get(entity, WantToAttack)[0];
        const targetIndex = target;

        var health = game.world.getPtr(targetIndex, Health) orelse continue;
        const damage = query.get(entity, component.Damage).v;
        health.current -= damage;
        if (health.current <= 0) {
            if (game.world.isIdentity(target, Player)) {
                game.turn = .over;
            } else game.world.destroyEntity(target);
        }
    }
    game.world.clear(WantToAttack);
}
