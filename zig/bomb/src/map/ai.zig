const std = @import("std");
const engine = @import("../engine.zig");
const World = @import("world.zig").World;
const Player = @import("player.zig").Player;

const enemySpeed = 500;

pub fn control(world: World) void {
    for (world.players) |*enemy| {
        if (enemy.type == .enemy and enemy.alive)
            controlEnemy(world, enemy);
    }
}

fn controlEnemy(world: World, enemy: *Player) void {
    const direction = enemy.direction orelse return;

    if (direction == .north) {
        var e = enemy.*;
        e.y -|= enemySpeed;
        if (world.isCollisionY(e, e.getCell().x, e.getCell().y -| 1)) {
            enemy.direction = @enumFromInt(engine.random(4));
        } else {
            enemy.y -|= enemySpeed;
        }
    }

    if (direction == .south) {
        var e = enemy.*;
        e.y -|= enemySpeed;
        if (world.isCollisionY(e, e.getCell().x, e.getCell().y + 1)) {
            enemy.direction = @enumFromInt(engine.random(4));
        } else {
            enemy.y += enemySpeed;
        }
    }

    if (direction == .west) {
        var e = enemy.*;
        e.x -|= enemySpeed;
        if (world.isCollisionY(e, e.getCell().x -| 1, e.getCell().y)) {
            enemy.direction = @enumFromInt(engine.random(4));
        } else {
            enemy.x -|= enemySpeed;
        }
    }

    if (direction == .east) {
        var e = enemy.*;
        e.x += enemySpeed;
        if (world.isCollisionY(e, e.getCell().x + 1, e.getCell().y)) {
            enemy.direction = @enumFromInt(engine.random(4));
        } else {
            enemy.x += enemySpeed;
        }
    }
}
