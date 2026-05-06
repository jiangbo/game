const std = @import("std");
const zhu = @import("zhu");

const com = @import("component.zig");
const spawn = @import("spawn.zig");

pub const PlayerEnum = com.PlayerEnum;

/// 角色槽位数据
pub const Unit = struct {
    name: [:0]const u8,
    face: u32,
    class: PlayerEnum,
    level: f32,
    rarity: f32,
    position: zhu.Vector2 = .zero,
    cost: f32 = 0,
};

const ContextZon = struct {
    level: u32,
    point: u32,
    units: []const Unit,
};

const contextZon: ContextZon = @import("zon/context.zon");
const INITIAL_COST: f32 = 10; // 初始 COST
const COST_GEN_PER_SECOND: f32 = 1; // 每秒恢复的 COST
const INITIAL_HOME_HEALTH: i32 = 5; // 初始基地生命值

// --- 场景状态 ---
pub const SceneState = enum { title, battle, clear, end };
pub var currentScene: SceneState = .title;

// --- 场景切换 ---
pub var pendingScene: ?SceneState = null;

// --- 全局状态 ---

pub var point: u32 = contextZon.point;
pub var levelClear: bool = false;
pub var win: bool = false;
pub var cost: f32 = INITIAL_COST;
pub var homeHealth: i32 = INITIAL_HOME_HEALTH;
pub var enemyCount: u32 = 0;
pub var enemyArrivedCount: u32 = 0;
pub var enemyKilledCount: u32 = 0;
pub var selected: ?usize = null;
pub var hoveredEntity: ?zhu.ecs.Entity = null;
pub var selectedEntity: ?zhu.ecs.Entity = null;
pub var uiWantCaptureMouse: bool = false;
pub var paused: bool = false;
pub var timeScale: f32 = 1;
pub var units: std.ArrayList(Unit) = .empty;
pub var unitLayoutDirty: bool = true;
// 地图数组中索引 0 是标题地图，关卡从索引 1 开始。
pub var levelIndex: usize = 0;

pub fn init() void {
    levelIndex = contextZon.level;
    reset();
}

pub fn deinit() void {
    units.deinit(zhu.assets.allocator);
}

/// 重置为默认存档数据，用于程序启动时初始化。
pub fn reset() void {
    resetBattle();
    point = contextZon.point;
    levelIndex = contextZon.level;
    levelClear = false;

    units.clearRetainingCapacity();
    for (contextZon.units) |zon| {
        var unit = zon;
        unit.cost = playerCost(unit.class, unit.rarity);
        units.append(zhu.assets.allocator, unit) catch @panic("oom");
    }

    sortUnitsByCost();
}

/// 重置单局战斗状态，不覆盖读档/升级得到的 Session 数据。
pub fn resetBattle() void {
    cost = INITIAL_COST;
    homeHealth = INITIAL_HOME_HEALTH;
    enemyCount = 0;
    enemyArrivedCount = 0;
    enemyKilledCount = 0;
    selected = null;
    hoveredEntity = null;
    selectedEntity = null;
    paused = false;
    timeScale = 1;
    win = false;
    unitLayoutDirty = true;
}

fn sortUnitsByCost() void {
    std.mem.sortUnstable(Unit, units.items, {}, struct {
        fn lessThan(_: void, a: Unit, b: Unit) bool {
            return a.cost < b.cost;
        }
    }.lessThan);
}

pub fn playerCost(playerEnum: PlayerEnum, rarity: f32) f32 {
    const base = spawn.playerZon[@intFromEnum(playerEnum)].cost;
    return @round(spawn.statModify(base, 1, rarity));
}

pub fn update(delta: f32) void {
    cost += COST_GEN_PER_SECOND * delta;
}

pub fn selectedUnit() ?Unit {
    return if (selected) |index| units.items[index] else null;
}

pub fn spendSelected() void {
    const index = selected.?;
    cost -= units.items[index].cost;
    _ = units.orderedRemove(index);
    selected = null;
    unitLayoutDirty = true;
}

pub fn isGameOver() bool {
    return homeHealth <= 0;
}

pub fn isLevelClear() bool {
    return enemyCount > 0 and
        enemyKilledCount + enemyArrivedCount >= enemyCount;
}

pub fn reward() u32 {
    return enemyKilledCount + @as(u32, @intCast(@max(0, homeHealth))) * 5;
}

const SaveData = struct {
    level: u32,
    point: u32,
    levelClear: bool,
    units: []const Unit,
};

pub fn saveGame(path: [:0]const u8) !void {
    const data = SaveData{
        .level = @intCast(levelIndex),
        .point = point,
        .levelClear = levelClear,
        .units = units.items,
    };

    var buf: [4096]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try std.zon.stringify.serialize(data, .{}, &writer);
    try zhu.window.saveAll(path, buf[0..writer.end]);
    std.log.info("save: {s}", .{path});
}

pub fn loadGame(path: [:0]const u8) !void {
    const content = try zhu.window.readAll(path);
    defer zhu.assets.allocator.free(content);

    const terminated = try std.fmt.allocPrintSentinel(
        zhu.assets.allocator,
        "{s}",
        .{content},
        0,
    );
    defer zhu.assets.allocator.free(terminated);

    const data = try std.zon.parse.fromSlice(
        SaveData,
        zhu.assets.allocator,
        terminated,
        null,
        .{},
    );
    defer std.zon.parse.free(zhu.assets.allocator, data);

    levelIndex = data.level;
    point = data.point;
    levelClear = data.levelClear;

    units.clearRetainingCapacity();
    for (data.units) |saveUnit| {
        var unit = saveUnit;
        unit.cost = playerCost(unit.class, unit.rarity);
        units.append(zhu.assets.allocator, unit) catch @panic("oom");
    }
    sortUnitsByCost();
    unitLayoutDirty = true;
    std.log.info("load: {s}", .{path});
}
