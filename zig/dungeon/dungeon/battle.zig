const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const component = @import("component.zig");

const Player = component.Player;
const Enemy = component.Enemy;
const WantToMove = component.WantToMove;
const TilePosition = component.TilePosition;
const WantToAttack = component.WantToAttack;
const Health = component.Health;
const TurnState = component.TurnState;

pub fn attack() void {
    var view = ecs.w.view(.{ WantToAttack, component.Damage });
    while (view.next()) |entity| {
        const target = view.get(entity, WantToAttack)[0];

        var health = ecs.w.tryGetPtr(target, Health) orelse continue;
        const damage = view.get(entity, component.Damage).v;
        health.current -= damage;
        if (health.current <= 0) {
            if (ecs.w.isIdentity(target, Player)) {
                ecs.w.addContext(TurnState.over);
            } else ecs.w.destroyEntity(target);
        }
    }
    ecs.w.clear(WantToAttack);
}
