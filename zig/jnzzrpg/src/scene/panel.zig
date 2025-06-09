const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");
const camera = @import("../camera.zig");
const battle = @import("battle.zig");

var attack: gfx.Texture = undefined;
var attackHover: gfx.Texture = undefined;
var item: gfx.Texture = undefined;
var itemHover: gfx.Texture = undefined;
var skill: gfx.Texture = undefined;
var skillHover: gfx.Texture = undefined;
var background: gfx.Texture = undefined;
var health: gfx.Texture = undefined;
var mana: gfx.Texture = undefined;

var selected: enum { attack, item, skill } = .attack;
pub var selectedPlayer: usize = 0;

pub fn init() void {
    attack = gfx.loadTexture("assets/fight/fm_b1_1.png", .init(38, 36));
    attackHover = gfx.loadTexture("assets/fight/fm_b1_2.png", .init(38, 36));
    item = gfx.loadTexture("assets/fight/fm_b2_1.png", .init(38, 36));
    itemHover = gfx.loadTexture("assets/fight/fm_b2_2.png", .init(38, 36));
    skill = gfx.loadTexture("assets/fight/fm_b3_1.png", .init(38, 36));
    skillHover = gfx.loadTexture("assets/fight/fm_b3_2.png", .init(38, 36));
    background = gfx.loadTexture("assets/fight/fm_bg.png", .init(319, 216));
    health = gfx.loadTexture("assets/fight/fm_s1.png", .init(129, 17));
    mana = gfx.loadTexture("assets/fight/fm_s2.png", .init(129, 17));
}

pub fn update(_: f32) void {
    if (battle.phase == .normal) return;

    if (battle.phase == .prepare) {
        if (window.isAnyKeyRelease(&.{ .LEFT, .A })) {
            selected = prevEnum(selected);
        }
        if (window.isAnyKeyRelease(&.{ .RIGHT, .D })) {
            selected = nextEnum(selected);
        }

        updatePrepare();
    } else if (battle.phase == .select) {
        switch (selected) {
            .attack => updateSelectAttack(),
            .skill => updateSelectSkill(),
            .item => updateSelectItem(),
        }
    }
}

pub fn onPlayerTurn(index: usize) void {
    battle.phase = .prepare;
    selectedPlayer = index;
    battle.selected = selectedPlayer;
}

fn updatePrepare() void {
    switch (selected) {
        .attack => {
            if (window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) {
                battle.phase = .select;
                std.log.info("select first enemy", .{});
                battle.selectFirstEnemy();
            }
        },
        .item, .skill => {},
    }
}

fn updateSelectAttack() void {
    if (window.isAnyKeyRelease(&.{ .D, .S, .DOWN, .RIGHT })) {
        battle.selectNextEnemy();
    }

    if (window.isAnyKeyRelease(&.{ .A, .W, .LEFT, .UP })) {
        battle.selectPrevEnemy();
    }

    if (window.isAnyKeyRelease(&.{ .ENTER, .SPACE, .F })) {
        battle.startAttackSelected(selectedPlayer, 1);
    }
}
fn updateSelectItem() void {}
fn updateSelectSkill() void {}

fn prevEnum(value: anytype) @TypeOf(value) {
    var number: usize = @intFromEnum(value);
    if (number == 0) number += enumLength(value);
    return @enumFromInt(number - 1);
}

fn nextEnum(value: anytype) @TypeOf(value) {
    const number: usize = @intFromEnum(value) + 1;
    return @enumFromInt(number % enumLength(value));
}

fn enumLength(value: anytype) usize {
    return @typeInfo(@TypeOf(value)).@"enum".fields.len;
}

const offset = gfx.Vector.init(200, 385);
pub fn render() void {
    camera.draw(background, offset);
    if (battle.selected < 3) renderPlayer() else renderEnemy();
}

fn renderPlayer() void {
    var texture = if (selected == .attack) attackHover else attack;
    camera.draw(texture, offset.add(.init(142, 68)));

    texture = if (selected == .item) itemHover else item;
    camera.draw(texture, offset.add(.init(192, 68)));

    texture = if (selected == .skill) skillHover else skill;
    camera.draw(texture, offset.add(.init(242, 68)));
    const player = &world.players[selectedPlayer];
    // 头像
    camera.draw(player.battleFace, offset);
    drawName(player.name, offset.add(.init(180, 114)));
    // 状态条
    var percent = computePercent(player.health, player.maxHealth);
    drawBar(percent, health, offset.add(.init(141, 145)));
    percent = computePercent(player.mana, player.maxMana);
    drawBar(percent, mana, offset.add(.init(141, 171)));
}

fn renderEnemy() void {
    const enemy = battle.currentSelectEnemy();
    drawName(enemy.name, offset.add(.init(180, 114)));
    // 状态条
    const percent = computePercent(enemy.health, enemy.maxHealth);
    drawBar(percent, health, offset.add(.init(141, 145)));
}

fn computePercent(current: usize, max: usize) f32 {
    if (max == 0) return 0;
    const cur: f32 = @floatFromInt(current);
    return cur / @as(f32, @floatFromInt(max));
}

fn drawBar(percent: f32, tex: gfx.Texture, pos: gfx.Vector) void {
    const width = tex.area.size().x * percent;
    camera.drawOptions(.{
        .texture = tex,
        .source = .init(.zero, .init(width, tex.area.size().y)),
        .target = .init(pos, .init(width, tex.area.size().y)),
    });
}

fn drawName(name: []const u8, pos: gfx.Vector) void {
    camera.drawTextOptions(.{
        .text = name,
        .position = pos,
        .color = gfx.Color{ .g = 0.05, .b = 0.16, .a = 1 },
    });
}

fn drawTextOptions(comptime fmt: []const u8, options: anytype) void {
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, fmt, options.args);
    camera.drawTextOptions(.{
        .text = text catch unreachable,
        .position = options.position,
        .color = options.color,
    });
}
