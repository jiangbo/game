const std = @import("std");
const zhu = @import("zhu");

const com = @import("component.zig");
const map = @import("map.zig");
const ctx = @import("context.zig");

const Registry = zhu.ecs.Registry;
const Entity = zhu.ecs.Entity;

pub const Sound = struct { action: com.ActionEnum, path: [:0]const u8 };
pub const Template = struct {
    enemyEnum: ?com.EnemyEnum = null,
    playerEnum: ?com.PlayerEnum = null,
    name: [:0]const u8,
    description: []const u8 = &.{},
    stats: com.Stats,
    block: u8 = 0,
    cost: f32 = 0,
    speed: f32 = 0,
    attackKind: map.PlaceKind = .melee,
    skill: ?com.skill.Skill = null,
    faceRight: bool,
    projectile: ?com.ProjectileEnum = null,
    size: zhu.Vector2,
    offset: zhu.Vector2,
    sounds: []const Sound = &.{},
    image: struct { path: [:0]const u8, size: zhu.Vector2 },
    animations: []const []const zhu.graphics.Frame = &.{},
};

pub const EnemyGroup = struct { class: com.EnemyEnum, count: u32 };

pub const Wave = struct {
    nextWaveInterval: f32,
    spawnInterval: f32,
    enemies: []const EnemyGroup,
};

pub const Level = struct {
    prepTime: f32,
    enemyLevel: f32,
    enemyRarity: f32,
    waves: []const Wave,
};

pub const Effect = struct {
    effectEnum: com.EffectEnum,
    position: zhu.Vector2 = .zero,
    size: zhu.Vector2,
    drawSize: ?zhu.Vector2 = null,
    offset: zhu.Vector2 = .zero,
    image: struct { path: [:0]const u8, size: zhu.Vector2 },
    animation: []const zhu.graphics.Frame,
};

pub const enemyZon: []const Template = @import("zon/enemy.zon");
pub const playerZon: []const Template = @import("zon/player.zon");
pub const levels: []const Level = @import("zon/levels.zon");
pub const effectZon: []const Effect = @import("zon/effect.zon");

// 下一次要启动的波次下标。
var nextWaveIndex: usize = 0;
var nextWaveTimer: ?zhu.Timer = null;
var spawnTimer: zhu.Timer = .init(0);
var enemyQueue: std.ArrayList(com.EnemyEnum) = .empty;

pub fn init() void {
    changeLevel(ctx.levelIndex);
}

/// 属性公式：基础值 × 等级系数 × 稀有度系数
pub fn statModify(base: f32, level: f32, rarity: f32) f32 {
    return base * (0.95 + 0.05 * level) * (0.9 + 0.1 * rarity);
}

fn applyLevelRarity(base: com.Stats, level: f32, rarity: f32) com.Stats {
    var stats = base;
    stats.health = statModify(base.maxHealth, level, rarity);
    stats.maxHealth = stats.health;
    stats.attack = statModify(base.attack, level, rarity);
    stats.defense = statModify(base.defense, level, rarity);
    stats.level = level;
    stats.rarity = rarity;
    return stats;
}

/// 升级单位：等级+1，从模板重算属性，生成升级特效。
pub fn upgradeUnit(reg: *Registry, entity: Entity) void {
    const playerEnum = reg.get(entity, com.PlayerEnum);
    const template = &playerZon[@intFromEnum(playerEnum)];

    const stats = reg.getPtr(entity, com.Stats);
    stats.level += 1;
    const level = stats.level;
    const rarity = stats.rarity;

    stats.maxHealth = statModify(template.stats.maxHealth, level, rarity);
    stats.health = stats.maxHealth;
    stats.attack = statModify(template.stats.attack, level, rarity);
    stats.defense = statModify(template.stats.defense, level, rarity);
    stats.range = template.stats.range;
    stats.interval = template.stats.interval;

    const position = reg.get(entity, com.Position);
    const effectEntity = effect(reg, .levelUp);
    reg.add(effectEntity, position);
    reg.add(effectEntity, com.DeadOnFinish{});

    zhu.audio.playSound("assets/audio/Fantasy_UI (10).ogg");
    std.log.info("upgrade entity: {}, level: {}", .{ entity.index, level });
}

pub fn changeLevel(levelIndex: usize) void {
    const level = levelData(levelIndex);

    ctx.levelIndex = levelIndex;
    nextWaveIndex = 0;
    nextWaveTimer = .init(level.prepTime);
    spawnTimer = .init(0);
    enemyQueue.clearRetainingCapacity();

    ctx.enemyCount = 0;
    for (level.waves) |wave| {
        for (wave.enemies) |enemy| ctx.enemyCount += enemy.count;
    }
}

pub fn hasNextLevel(levelIndex: usize) bool {
    return levelIndex > 0 and levelIndex < levels.len;
}

fn levelData(levelIndex: usize) Level {
    const dataIndex = if (levelIndex == 0) 0 else levelIndex - 1;
    return levels[dataIndex];
}

pub fn remainingWaveCount() usize {
    return levelData(ctx.levelIndex).waves.len - nextWaveIndex;
}

pub fn nextWaveSeconds() ?f32 {
    const timer = nextWaveTimer orelse return null;
    return @max(0, timer.duration - timer.elapsed);
}

pub fn deinit() void {
    enemyQueue.deinit(zhu.assets.allocator);
}

pub fn update(reg: *Registry, delta: f32) void {
    const level = levelData(ctx.levelIndex);

    // 下一波倒计时独立推进，和当前波敌人是否刷完无关。
    if (nextWaveTimer) |*timer| {
        if (timer.isFinishedOnceUpdate(delta)) {
            startWave(level.waves[nextWaveIndex]);
        }
    }

    // 当前波的敌人生成完成了
    if (enemyQueue.items.len == 0) return;
    if (spawnTimer.isFinishedLoopUpdate(delta)) {
        spawnEnemy(reg, enemyQueue.pop().?);
    }
}

/// 开始一波：展开敌人分组，并设置本波生成间隔和下一波倒计时。
fn startWave(wave: Wave) void {
    nextWaveIndex += 1;
    for (wave.enemies) |enemy| {
        enemyQueue.appendNTimes(zhu.assets.allocator, enemy.class, //
            enemy.count) catch @panic("oom, can't append enemy");
    }
    zhu.random().shuffle(com.EnemyEnum, enemyQueue.items);

    spawnTimer = .initFinished(wave.spawnInterval);
    nextWaveTimer = .init(wave.nextWaveInterval);
    // 如果没有下一波了，就不需要倒计时了。
    const len = levelData(ctx.levelIndex).waves.len;
    if (nextWaveIndex >= len) nextWaveTimer = null;
}

fn spawnEnemy(reg: *Registry, enemyEnum: com.EnemyEnum) void {
    var startCount: usize = 0;
    for (map.startPaths) |startId| {
        if (startId == 0) break else startCount += 1;
    }

    const startIndex = zhu.randomInt(usize, 0, startCount);
    const start = map.paths.get(map.startPaths[startIndex]).?;
    const template = &enemyZon[@intFromEnum(enemyEnum)];
    const entity = doSpawn(reg, template);
    reg.add(entity, enemyEnum);

    const level = levelData(ctx.levelIndex);
    reg.getPtr(entity, com.Stats).* = applyLevelRarity(
        template.stats,
        level.enemyLevel,
        level.enemyRarity,
    );

    reg.add(entity, start.point);
    reg.add(entity, com.motion.Velocity{ .v = .zero });
    reg.add(entity, com.Enemy{
        .target = start,
        .speed = template.speed,
    });

    const index: u8 = @intFromEnum(com.StateEnum.walk);
    reg.getPtr(entity, com.Animation).play(index, true);
    std.log.info("spawn enemy: {}", .{entity.index});
}

fn doSpawn(reg: *Registry, zon: *const Template) zhu.ecs.Entity {
    const entity = reg.createEntity();

    const imagePath = zon.image.path;
    const image = zhu.assets.loadImage(imagePath, zon.image.size);
    reg.add(entity, com.Sprite{
        .image = image.sub(.init(.zero, zon.size)),
        .offset = zon.offset,
    });

    // 面向左侧
    if (!zon.faceRight) reg.add(entity, com.motion.FaceLeft{});

    if (zon.block != 0) {
        reg.add(entity, com.motion.Blocker{ .max = zon.block });
    }

    const animation = com.Animation.initSource(image, zon.animations);
    reg.add(entity, animation);

    // 添加远程攻击
    if (zon.attackKind == .ranged) reg.add(entity, com.attack.Ranged{});

    // 添加属性组件
    reg.add(entity, zon.stats);

    // 添加职业组件。玩家姓名由出击单位数据提供。
    reg.add(entity, com.ClassName{ .value = zon.name });
    if (zon.stats.attack < 0) reg.add(entity, com.attack.Healer{});
    if (zon.stats.health < zon.stats.maxHealth) {
        reg.add(entity, com.attack.Injured{});
    }

    // 添加投射物组件
    if (zon.projectile) |value| reg.add(entity, value);

    // 攻击就绪
    reg.add(entity, com.attack.Ready{});

    // 添加声音组件
    for (zon.sounds) |sound| {
        const path = sound.path;
        switch (sound.action) {
            .hit => reg.add(entity, com.audio.Hit{ .path = path }),
            .emit => reg.add(entity, com.audio.Emit{ .path = path }),
            else => {},
        }
    }
    return entity;
}

/// 尝试在合法出击区域部署玩家单位
pub fn tryDeployPlayer(reg: *Registry, unit: ctx.Unit) void {
    const template = &playerZon[@intFromEnum(unit.class)];
    const mousePos = zhu.window.mousePosition;

    if (map.findPlace(template.attackKind, mousePos)) |idx| {
        if (ctx.cost < unit.cost) return;

        const place = &map.places.items[idx];
        const center = place.position.add(place.size.scale(0.5));

        const entity = doSpawn(reg, template);
        reg.add(entity, unit.class);

        // 覆盖为玩家实体的等级和稀有度
        reg.getPtr(entity, com.Stats).* = applyLevelRarity(
            template.stats,
            unit.level,
            unit.rarity,
        );

        reg.add(entity, com.Name{ .value = unit.name });
        reg.add(entity, center);
        reg.add(entity, com.Player{ .cost = unit.cost });
        if (template.skill) |skill| addSkill(reg, entity, skill);
        place.entity = entity;

        ctx.spendSelected();
        zhu.audio.playSound("assets/audio/Fantasy_UI (10).ogg");
        std.log.info("player deployed: {}", .{entity.index});
    }
}

fn addSkill(reg: *Registry, entity: zhu.ecs.Entity, skill: com.skill.Skill) void {
    if (skill.passive) {
        reg.add(entity, skill);
        reg.add(entity, com.skill.Passive{});
        reg.add(entity, com.skill.Active{});
        if (skill.costRecovery != 0) {
            reg.add(entity, com.skill.CostRecovery{
                .rate = skill.costRecovery,
            });
        }
        return;
    }

    reg.add(entity, skill);

    if (skill.coolDown <= 0) {
        reg.add(entity, com.skill.Ready{});
        return;
    }

    reg.add(entity, com.skill.Timer.init(skill.coolDown / 2));
}

/// 复制敌人精灵播放受伤动画，动画结束后自动销毁。
pub fn deadEnemy(reg: *Registry, entity: Entity) void {
    const sprite = reg.get(entity, com.Sprite);
    const position = reg.get(entity, com.Position);
    var animation = reg.get(entity, com.Animation);

    const damageIndex: u8 = @intFromEnum(com.StateEnum.damage);
    animation.play(damageIndex, false);

    const newEntity = reg.createEntity();
    reg.add(newEntity, sprite);
    reg.add(newEntity, position);
    reg.add(newEntity, animation);
    reg.add(newEntity, com.DeadOnFinish{});
}

/// 根据 effectZon 数据创建特效实体，位置和生命周期由调用方处理。
pub fn effect(reg: *Registry, effectEnum: com.EffectEnum) Entity {
    const value = &effectZon[@intFromEnum(effectEnum)];
    const entity = reg.createEntity();
    const image = zhu.assets.loadImage(value.image.path, .zero);

    reg.add(entity, com.Sprite{
        .image = image.sub(.init(value.position, value.size)),
        .offset = value.offset,
        .size = value.drawSize,
    });
    var animation = com.Animation.init(image, value.animation);
    animation.loop = false;
    reg.add(entity, animation);
    return entity;
}

/// 释放被该实体占用的出击点
pub fn releasePlace(entity: zhu.ecs.Entity) void {
    for (map.places.items) |*place| {
        if (place.entity) |pe| {
            if (std.meta.eql(pe, entity)) {
                place.entity = null;
                return;
            }
        }
    }
}

const Projectile = struct {
    image: [:0]const u8,
    position: zhu.Vector2,
    size: zhu.Vector2,
    offset: zhu.Vector2,
    arc: f32,
    time: f32,
};

const projectileZon: []const Projectile = @import("zon/projectile.zon");

pub fn projectile(reg: *Registry, delta: f32) void {
    defer reg.clear(com.attack.Emit);
    var view = reg.view(.{com.attack.Emit});
    while (view.next()) |entity| {
        // 检查目标是否还有效
        var targetEntity: ?Entity = null;
        var targetPos: ?zhu.Vector2 = null;
        if (view.tryGet(entity, com.attack.Target)) |target| {
            if (reg.validEntity(target.v)) {
                targetEntity = target.v;
                targetPos = reg.get(target.v, com.Position);
            }
        }
        if (targetPos == null) continue; // 目标无效，跳过生成投射物

        const template = view.get(entity, com.ProjectileEnum);
        const value = &projectileZon[@intFromEnum(template)];

        const damage = view.get(entity, com.Stats).attack;
        const new = reg.createEntity();
        const image = zhu.assets.loadImage(value.image, .zero);
        const start = view.get(entity, com.Position);
        const drawStart = start.add(value.offset);
        reg.add(new, image.sub(.init(value.position, value.size)));
        reg.add(new, com.Projectile{
            .start = start,
            .end = targetPos.?,
            .previous = drawStart,
            .arc = value.arc,
            .totalTime = value.time + delta,
            .owner = view.toEntity(entity),
            .target = targetEntity.?,
            .damage = damage,
            .offset = value.offset,
        });

        reg.add(new, drawStart);

        if (view.tryGet(entity, com.audio.Emit)) |emitSound| {
            zhu.audio.playSound(emitSound.path); // 播放发射声音
        }

        std.log.info("entity: {} emit: {}", .{ entity, new.index });
    }
}
