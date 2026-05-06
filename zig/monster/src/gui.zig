const std = @import("std");
const sk = @import("sokol");
const zhu = @import("zhu");

const gui = @import("cimgui");

const com = @import("component.zig");
const ctx = @import("context.zig");
const spawn = @import("spawn.zig");
const scene = @import("scene.zig");
const title = @import("title.zig");
const Registry = zhu.ecs.Registry;

pub fn init() void {
    sk.imgui.setup(.{
        .logger = .{ .func = sk.log.func },
        .no_default_font = true,
        .ini_filename = "assets/imgui.ini",
    });

    const io = gui.igGetIO();
    const font = io.*.Fonts;
    const range = gui.ImFontAtlas_GetGlyphRangesChineseSimplifiedCommon(font);
    const chineseFont = gui.ImFontAtlas_AddFontFromFileTTF(font, //
        "assets/VonwaonBitmap-16px.ttf", 16, null, range);

    if (chineseFont == null) @panic("failed to load font");

    gui.igStyleColorsDark(null);
    const style = gui.igGetStyle();
    const windowAlpha: f32 = 0.5;
    style.*.Colors[gui.ImGuiCol_WindowBg].w = windowAlpha;
    style.*.Colors[gui.ImGuiCol_PopupBg].w = windowAlpha;
}

pub fn event(ev: *const zhu.window.Event) void {
    _ = sk.imgui.handleEvent(ev.*);
}

pub fn update(reg: *Registry, delta: f32) void {
    sk.imgui.newFrame(.{
        .width = sk.app.width(),
        .height = sk.app.height(),
        .delta_time = delta,
    });

    switch (ctx.currentScene) {
        .title => {
            renderTitleButtons();
            renderTitleUI();
        },
        .battle => {
            if (zhu.input.key.pressed(.P)) ctx.paused = !ctx.paused;

            renderHoveredUnit(reg);
            renderSelectedUnit(reg);
            renderBattleUI(reg);
        },
        .clear => renderLevelClear(),
        .end => renderEndScene(),
    }

    const io = gui.igGetIO();
    ctx.uiWantCaptureMouse = io.*.WantCaptureMouse;
}

var showUnitInfo: bool = false;
var showLoadPanel: bool = false;
var showSavePanel: bool = false;
var showDebugTools: bool = false;

fn renderTitleButtons() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("TitleUI", null, flags)) {
        gui.igSetWindowFontScale(2.0);
        if (gui.igButtonEx("开始游戏", .{ .x = 200, .y = 60 })) {
            title.startGame();
        }
        gui.igSameLine();
        gui.igSetCursorPosX(gui.igGetCursorPosX() + 20);
        if (gui.igButtonEx("确认角色", .{ .x = 200, .y = 60 })) {
            showUnitInfo = !showUnitInfo;
        }
        gui.igSameLine();
        gui.igSetCursorPosX(gui.igGetCursorPosX() + 20);
        if (gui.igButtonEx("载入游戏", .{ .x = 200, .y = 60 })) {
            showLoadPanel = !showLoadPanel;
        }
        gui.igSameLine();
        gui.igSetCursorPosX(gui.igGetCursorPosX() + 20);
        if (gui.igButtonEx("退出游戏", .{ .x = 200, .y = 60 })) {
            zhu.window.exit();
        }
        gui.igSetWindowFontScale(1.0);
    }
    gui.igEnd();

    if (showUnitInfo) renderUnitInfo();
    if (showLoadPanel) renderLoadPanel();
}

fn renderHoveredUnit(reg: *Registry) void {
    const entity = ctx.hoveredEntity orelse return;
    const stats = reg.tryGet(entity, com.Stats) orelse return;

    if (gui.igBeginTooltip()) {
        if (reg.tryGet(entity, com.Name)) |name| {
            _ = gui.igText("%s  ", name.value.ptr);
            gui.igSameLine();
        }

        if (reg.tryGet(entity, com.ClassName)) |className| {
            _ = gui.igText("%s", className.value.ptr);
        }

        _ = gui.igText("等级: %.0f", stats.level);
        gui.igSameLine();
        _ = gui.igText("稀有度: %.0f", stats.rarity);
        _ = gui.igText("生命值: %.0f / %.0f", stats.health, stats.maxHealth);
        _ = gui.igText("攻击力: %.0f", stats.attack);
        _ = gui.igText("防御力: %.0f", stats.defense);
        _ = gui.igText("攻击范围: %d", @as(i32, @intFromFloat(stats.range)));
        _ = gui.igText("攻击间隔: %.2f", stats.interval);

        gui.igEndTooltip();
    }
}

fn renderSelectedUnit(reg: *Registry) void {
    const entity = ctx.selectedEntity orelse return;
    const stats = reg.tryGet(entity, com.Stats) orelse return;

    gui.igSetNextWindowPos(.{ .x = 10, .y = 10 }, gui.ImGuiCond_Always);
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("角色状态", null, flags)) {
        if (reg.tryGet(entity, com.Name)) |name| {
            _ = gui.igText("%s  ", name.value.ptr);
            gui.igSameLine();
        }

        if (reg.tryGet(entity, com.ClassName)) |className| {
            _ = gui.igText("%s", className.value.ptr);
        }

        _ = gui.igText("等级: %.0f", stats.level);
        gui.igSameLine();
        _ = gui.igText("稀有度: %.0f", stats.rarity);
        _ = gui.igText("生命值: %.0f / %.0f", stats.health, stats.maxHealth);
        _ = gui.igText("攻击力: %.0f", stats.attack);
        gui.igSameLine();
        _ = gui.igText("防御力: %.0f", stats.defense);
        _ = gui.igText("攻击范围: %.0f", stats.range);
        gui.igSameLine();
        _ = gui.igText("攻击间隔: %.2f", stats.interval);

        if (reg.tryGet(entity, com.motion.Blocker)) |blocker| {
            _ = gui.igText("阻挡数量: %d / %d", blocker.current, blocker.max);
        }

        renderSelectedUpgrade(reg, entity);
        renderSelectedLeave(reg, entity);
        renderSelectedSkill(reg, entity);
    }
    gui.igEnd();
}

fn renderSelectedSkill(reg: *Registry, entity: zhu.ecs.Entity) void {
    const value = reg.tryGet(entity, com.skill.Skill) orelse return;
    const ready = reg.has(entity, com.skill.Ready);
    const active = reg.has(entity, com.skill.Active);
    const passive = value.passive or reg.has(entity, com.skill.Passive);

    gui.igBeginDisabled(!ready);
    const clicked = gui.igButton(value.name.ptr);
    gui.igEndDisabled();
    if (ready and (clicked or zhu.input.key.pressed(.S))) {
        reg.add(entity, com.skill.Cast{});
    }
    gui.igSameLine();

    if (active) {
        if (passive) {
            _ = gui.igText("被动技能激活中");
        } else if (reg.tryGet(entity, com.skill.Timer)) |timer| {
            const remaining = @max(0, value.duration - timer.elapsed);
            _ = gui.igText("激活中，剩余时间: %.1f 秒", remaining);
        }
    } else if (passive) {
        _ = gui.igText("被动技能");
    } else {
        _ = gui.igText("快捷键 S:");
        gui.igSameLine();
        if (ready) {
            _ = gui.igText("技能准备就绪");
        } else if (reg.tryGet(entity, com.skill.Timer)) |timer| {
            gui.igProgressBar(timer.progress(), .{ .x = 120, .y = 0 }, null);
        }
    }

    _ = gui.igTextWrapped("%s", value.description.ptr);
}

fn renderSelectedUpgrade(reg: *Registry, entity: zhu.ecs.Entity) void {
    if (!reg.has(entity, com.Player)) return;

    const player = reg.get(entity, com.Player);
    const upgradeCost = player.cost;

    gui.igBeginDisabled(ctx.cost < upgradeCost);
    const clicked = gui.igButton("升级");
    gui.igEndDisabled();
    gui.igSameLine();
    _ = gui.igText("快捷键 U: COST消费: %.0f", upgradeCost);

    if (ctx.cost >= upgradeCost and (clicked or zhu.input.key.pressed(.U))) {
        ctx.cost -= upgradeCost;
        spawn.upgradeUnit(reg, entity);
    }
}

fn renderSelectedLeave(reg: *Registry, entity: zhu.ecs.Entity) void {
    if (!reg.has(entity, com.Player)) return;

    const player = reg.get(entity, com.Player);
    const refund = player.cost * 0.5;

    if (gui.igButton("撤退") or zhu.input.key.pressed(.R)) {
        ctx.cost += refund;
        reg.add(entity, com.Dead{});
        ctx.selectedEntity = null;
    }
    gui.igSameLine();
    _ = gui.igText("快捷键 R: COST返还: %.0f", refund);
}

fn renderUnitInfo() void {
    if (!gui.igBegin("角色信息", &showUnitInfo, gui.ImGuiWindowFlags_NoCollapse)) {
        gui.igEnd();
        return;
    }
    renderUnitTable();
    gui.igSeparator();
    _ = gui.igText("剩余点数: %d", ctx.point);
    gui.igEnd();
}

fn renderUnitTable() void {
    const flags = gui.ImGuiTableFlags_SizingFixedFit | gui.ImGuiTableFlags_Sortable;
    if (!gui.igBeginTable("角色信息", 14, flags)) return;

    gui.igTableSetupColumn("姓名", 0);
    gui.igTableSetupColumn("职业", 0);
    gui.igTableSetupColumn("类型", 0);
    gui.igTableSetupColumn("等级", 0);
    gui.igTableSetupColumn("稀有度", 0);
    gui.igTableSetupColumn("COST", 0);
    gui.igTableSetupColumn("生命值", 0);
    gui.igTableSetupColumn("攻击力", 0);
    gui.igTableSetupColumn("防御力", 0);
    gui.igTableSetupColumn("攻击范围", 0);
    gui.igTableSetupColumn("攻击间隔", 0);
    gui.igTableSetupColumn("阻挡数量", 0);
    gui.igTableSetupColumn("技能", 0);
    gui.igTableSetupColumn("升级", 0);
    gui.igTableHeadersRow();

    sortUnitTable();

    for (ctx.units.items) |*unit| {
        const template = &spawn.playerZon[@intFromEnum(unit.class)];
        const hp = spawn.statModify(template.stats.maxHealth, unit.level, unit.rarity);
        const atk = spawn.statModify(template.stats.attack, unit.level, unit.rarity);
        const def = spawn.statModify(template.stats.defense, unit.level, unit.rarity);
        const upgradeCost: u32 = @intFromFloat(ctx.playerCost(unit.class, unit.rarity));
        const skillName = if (template.skill) |skill| skill.name else "";

        gui.igTableNextRow();
        _ = gui.igTableNextColumn();
        _ = gui.igText("%s", unit.name.ptr);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%s", template.name.ptr);
        gui.igSetItemTooltip("%s", template.description.ptr);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%s", playerTypeName(template.attackKind).ptr);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%.0f", unit.level);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%.0f", unit.rarity);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%.0f", unit.cost);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%.0f", hp);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%.0f", atk);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%.0f", def);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%.0f", template.stats.range);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%.2f", template.stats.interval);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%d", template.block);
        _ = gui.igTableNextColumn();
        _ = gui.igText("%s", skillName.ptr);
        if (template.skill) |skill| gui.igSetItemTooltip("%s", skill.description.ptr);
        _ = gui.igTableNextColumn();

        gui.igPushID(unit.name);
        const canUpgrade = ctx.point >= upgradeCost;
        gui.igBeginDisabled(!canUpgrade);
        var btnText: [32]u8 = undefined;
        const btnLabel = std.fmt.bufPrintZ(&btnText, "- {}", .{upgradeCost}) catch unreachable;
        const clicked = gui.igButton(btnLabel);
        gui.igEndDisabled();
        if (canUpgrade and clicked) {
            ctx.point -= upgradeCost;
            unit.level += 1;
            unit.cost = ctx.playerCost(unit.class, unit.rarity);
        }
        gui.igPopID();
        gui.igSetItemTooltip("升级耗费的点数：%d", upgradeCost);
    }
    gui.igEndTable();
}

fn playerTypeName(attackKind: @TypeOf(spawn.playerZon[0].attackKind)) [:0]const u8 {
    return switch (attackKind) {
        .melee => "近战",
        .ranged => "远程",
    };
}

fn sortUnitTable() void {
    const sortSpecs = gui.igTableGetSortSpecs();
    if (sortSpecs == null or !sortSpecs.*.SpecsDirty or ctx.units.items.len == 0) return;

    const spec = sortSpecs.*.Specs[0];
    if (spec.SortDirection == gui.ImGuiSortDirection_None) return;

    const sort = UnitSort{
        .column = spec.ColumnIndex,
        .ascending = spec.SortDirection == gui.ImGuiSortDirection_Ascending,
    };
    std.mem.sort(ctx.Unit, ctx.units.items, sort, UnitSort.lessThan);
    sortSpecs.*.SpecsDirty = false;
}

const UnitSort = struct {
    column: c_int,
    ascending: bool,

    fn lessThan(self: UnitSort, a: ctx.Unit, b: ctx.Unit) bool {
        const delta = compareUnit(self.column, a, b);
        return if (self.ascending) delta < 0 else delta > 0;
    }
};

fn compareUnit(column: c_int, a: ctx.Unit, b: ctx.Unit) i32 {
    const ta = &spawn.playerZon[@intFromEnum(a.class)];
    const tb = &spawn.playerZon[@intFromEnum(b.class)];
    const sa = if (ta.skill) |skill| skill.name else "";
    const sb = if (tb.skill) |skill| skill.name else "";

    const delta = switch (column) {
        0 => compareText(a.name, b.name),
        1 => compareText(ta.name, tb.name),
        2 => compareInt(@intFromEnum(ta.attackKind), @intFromEnum(tb.attackKind)),
        3 => compareFloat(a.level, b.level),
        4 => compareFloat(a.rarity, b.rarity),
        5, 13 => compareFloat(a.cost, b.cost),
        6 => compareFloat(
            spawn.statModify(ta.stats.maxHealth, a.level, a.rarity),
            spawn.statModify(tb.stats.maxHealth, b.level, b.rarity),
        ),
        7 => compareFloat(
            spawn.statModify(ta.stats.attack, a.level, a.rarity),
            spawn.statModify(tb.stats.attack, b.level, b.rarity),
        ),
        8 => compareFloat(
            spawn.statModify(ta.stats.defense, a.level, a.rarity),
            spawn.statModify(tb.stats.defense, b.level, b.rarity),
        ),
        9 => compareFloat(ta.stats.range, tb.stats.range),
        10 => compareFloat(ta.stats.interval, tb.stats.interval),
        11 => compareInt(ta.block, tb.block),
        12 => compareText(sa, sb),
        else => 0,
    };
    return if (delta != 0) delta else compareText(a.name, b.name);
}

fn compareText(a: []const u8, b: []const u8) i32 {
    return switch (std.mem.order(u8, a, b)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

fn compareFloat(a: f32, b: f32) i32 {
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
}

fn compareInt(a: anytype, b: @TypeOf(a)) i32 {
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
}

const slots = [_][:0]const u8{
    "assets/save/SLOT_1.zon",
    "assets/save/SLOT_2.zon",
    "assets/save/SLOT_3.zon",
};

fn renderLoadPanel() void {
    if (!gui.igBegin("读档选择", &showLoadPanel, gui.ImGuiWindowFlags_NoCollapse)) {
        gui.igEnd();
        return;
    }
    for (slots, 0..) |slot, i| {
        var lbl: [16]u8 = undefined;
        const text = std.fmt.bufPrintZ(&lbl, "SLOT {}", .{i + 1}) catch unreachable;
        if (gui.igButton(text)) {
            ctx.loadGame(slot) catch |err| {
                std.log.err("load failed: {s}, {}", .{ slot, err });
                continue;
            };
        }
        gui.igSameLine();
    }
    if (ctx.levelClear and spawn.hasNextLevel(ctx.levelIndex)) {
        _ = gui.igText("下一关: %d", ctx.levelIndex + 1);
    } else if (ctx.levelClear) {
        _ = gui.igText("已通关");
    } else {
        _ = gui.igText("当前关卡: %d", ctx.levelIndex);
    }
    gui.igEnd();
}

fn renderSavePanel() void {
    if (!gui.igBegin("存档选择", &showSavePanel, gui.ImGuiWindowFlags_NoCollapse)) {
        gui.igEnd();
        return;
    }
    for (slots, 0..) |slot, i| {
        var lbl: [16]u8 = undefined;
        const text = std.fmt.bufPrintZ(&lbl, "SLOT {}", .{i + 1}) catch unreachable;
        if (gui.igButton(text)) {
            ctx.saveGame(slot) catch |err| {
                std.log.err("save failed: {s}, {}", .{ slot, err });
                continue;
            };
        }
        gui.igSameLine();
    }
    if (ctx.levelClear and spawn.hasNextLevel(ctx.levelIndex)) {
        _ = gui.igText("下一关: %d", ctx.levelIndex + 1);
    } else if (ctx.levelClear) {
        _ = gui.igText("已通关");
    } else {
        _ = gui.igText("当前关卡: %d", ctx.levelIndex);
    }
    gui.igEnd();
}

pub fn draw(reg: *Registry) void {
    _ = reg;
    sk.imgui.render();
}

fn renderTitleUI() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_NoBackground |
        gui.ImGuiWindowFlags_NoInputs;
    if (gui.igBegin("TitleLogo", null, flags)) {}
    gui.igEnd();
}

fn renderBattleUI(reg: *Registry) void {
    renderLevelInfo();
    renderSettings(reg);
    renderDebugTools();
    if (showSavePanel) renderSavePanel();
}

fn renderLevelInfo() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("关卡信息", null, flags)) {
        _ = gui.igText("基地血量: %d / 5", ctx.homeHealth);
        gui.igSameLine();
        _ = gui.igText("COST: %.0f", ctx.cost);
        gui.igSameLine();
        _ = gui.igText("剩余波次: %d", spawn.remainingWaveCount());
        if (spawn.nextWaveSeconds()) |seconds| {
            gui.igSameLine();
            _ = gui.igText("下一波时间: %d", @as(i32, @intFromFloat(seconds)));
        }
        gui.igSameLine();
        _ = gui.igText("击杀数量: %d / %d", ctx.enemyKilledCount, ctx.enemyCount);
        gui.igSameLine();
        _ = gui.igText("当前关卡: %d", ctx.levelIndex);
        if (ctx.paused) {
            gui.igSameLine();
            _ = gui.igText("已暂停");
        }
    }
    gui.igEnd();
}

fn renderSettings(reg: *Registry) void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("设置工具", null, flags)) {
        if (gui.igButton(if (ctx.paused) "继续游戏" else "暂停游戏")) {
            ctx.paused = !ctx.paused;
        }
        gui.igSameLine();
        if (gui.igButton("重新开始")) {
            scene.restart(reg);
        }
        if (gui.igButton("返回标题")) {
            ctx.pendingScene = .title;
        }
        gui.igSameLine();
        if (gui.igButton("保存")) {
            showSavePanel = !showSavePanel;
        }
        gui.igSeparator();

        if (gui.igButton("0.5倍速")) ctx.timeScale = 0.5;
        gui.igSameLine();
        if (gui.igButton("1倍速")) ctx.timeScale = 1;
        gui.igSameLine();
        if (gui.igButton("2倍速")) ctx.timeScale = 2;
        _ = gui.igSliderFloat("游戏速度", &ctx.timeScale, 0.5, 2);

        var music: f32 = zhu.audio.musicVolume.load(.acquire);
        if (gui.igSliderFloat("音乐音量", &music, 0, 1)) {
            zhu.audio.musicVolume.store(music, .release);
        }
        var sound: f32 = zhu.audio.soundVolume.load(.acquire);
        if (gui.igSliderFloat("音效音量", &sound, 0, 1)) {
            zhu.audio.soundVolume.store(sound, .release);
        }
        _ = gui.igCheckbox("显示调试工具", &showDebugTools);
    }
    gui.igEnd();
}

fn renderDebugTools() void {
    if (!showDebugTools) return;
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("调试工具", null, flags)) {
        if (gui.igButton("COST + 10")) ctx.cost += 10;
        if (gui.igButton("COST + 100")) ctx.cost += 100;
        if (gui.igButton("通关")) {
            ctx.enemyKilledCount = ctx.enemyCount;
        }
    }
    gui.igEnd();
}

fn renderLevelClear() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("通关结算文本", null, flags)) {
        gui.igSetWindowFontScale(3.0);
        _ = gui.igText("通关成功！");
        gui.igSetWindowFontScale(1.0);
    }
    gui.igEnd();

    if (gui.igBegin("通关结算", null, gui.ImGuiWindowFlags_NoTitleBar)) {
        renderUnitTable();
        gui.igSeparator();
        _ = gui.igText("关卡: %d", ctx.levelIndex);
        gui.igSameLine();
        _ = gui.igText("击杀数量: %d / %d", ctx.enemyKilledCount, ctx.enemyCount);
        gui.igSameLine();
        _ = gui.igText("基地血量: %d / 5", ctx.homeHealth);
        gui.igSameLine();
        _ = gui.igText("奖励点数: %d", ctx.reward());
        gui.igSameLine();
        _ = gui.igText("剩余点数: %d", ctx.point);
    }
    gui.igEnd();

    if (gui.igBegin("通关结算按钮", null, flags)) {
        gui.igSetWindowFontScale(1.5);
        if (gui.igButtonEx("下一关", .{ .x = 150, .y = 45 })) {
            ctx.levelClear = false;
            if (spawn.hasNextLevel(ctx.levelIndex)) {
                ctx.levelIndex += 1;
                ctx.pendingScene = .battle;
            } else {
                ctx.win = true;
                ctx.pendingScene = .end;
            }
        }
        gui.igSameLine();
        gui.igSetCursorPosX(gui.igGetCursorPosX() + 20);
        if (gui.igButtonEx("保存", .{ .x = 150, .y = 45 })) {
            showSavePanel = !showSavePanel;
        }
        gui.igSameLine();
        gui.igSetCursorPosX(gui.igGetCursorPosX() + 20);
        if (gui.igButtonEx("返回标题", .{ .x = 150, .y = 45 })) {
            ctx.pendingScene = .title;
        }
        gui.igSetWindowFontScale(1.0);
    }
    gui.igEnd();

    if (showSavePanel) renderSavePanel();
}

fn renderEndScene() void {
    const flags = gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_AlwaysAutoResize;
    if (gui.igBegin("Game End", null, flags)) {
        gui.igSetWindowFontScale(5.0);
        if (ctx.win) {
            _ = gui.igText("恭喜你，游戏胜利!");
        } else {
            _ = gui.igText("游戏失败，请再接再厉！");
        }
        gui.igSetWindowFontScale(1.0);
    }
    gui.igEnd();

    if (gui.igBegin("游戏结束按钮", null, flags)) {
        gui.igSetWindowFontScale(1.5);
        if (gui.igButtonEx("返回标题", .{ .x = 150, .y = 45 })) {
            ctx.pendingScene = .title;
        }
        gui.igSameLine();
        gui.igSetCursorPosX(gui.igGetCursorPosX() + 20);
        if (gui.igButtonEx("退出游戏", .{ .x = 150, .y = 45 })) {
            zhu.window.exit();
        }
        gui.igSetWindowFontScale(1.0);
    }
    gui.igEnd();
}

pub fn deinit() void {
    sk.imgui.shutdown();
}
