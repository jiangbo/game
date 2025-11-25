const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const ecs = zhu.ecs;

const map = @import("map.zig");
const player = @import("player.zig");
const monster = @import("monster.zig");
const hud = @import("hud.zig");
const battle = @import("battle.zig");
const component = @import("component.zig");
const item = @import("item.zig");

const Player = component.Player;
const Position = component.Position;
const TilePosition = component.TilePosition;
const WantToMove = component.WantToMove;
const TurnState = component.TurnState;
const PlayerView = component.PlayerView;

var isHelp = false;
var isDebug = false;

pub fn init() void {
    window.initFont(.{
        .font = @import("zon/font.zon"),
        .texture = gfx.loadTexture("assets/font.png", .init(960, 960)),
    });

    camera.frameStats(true);
    camera.init(5000);
    ecs.init(window.allocator);

    restart();
}

fn restart() void {
    ecs.clear();
    initWorld(1);
}

fn initWorld(mapLevel: u8) void {
    ecs.w.addContext(TurnState.player);
    hud.init();
    map.init(mapLevel);
    player.init();
    item.init();
    monster.init();
}

fn nextLevel() void {
    var reg = ecs.Registry.init(window.allocator);
    // 保留拾取的物品
    var view = ecs.w.view(.{component.Carried});
    while (view.next()) |entity| {
        const newEntity = reg.createEntity();
        reg.add(newEntity, component.Carried{});
        reg.add(newEntity, component.Item{});
        reg.add(newEntity, component.PlayerView{});
        if (view.tryGet(entity, component.Healing)) |heal| {
            reg.add(newEntity, heal);
        }
        if (view.tryGet(entity, component.Damage)) |damage| {
            reg.add(newEntity, damage);
        }
        reg.add(newEntity, view.get(entity, component.Name));
    }
    // 保留角色攻击力
    const damage = ecs.w.get(player.entity, component.Damage);
    const health = ecs.w.get(player.entity, component.Health);

    ecs.w.deinit();
    ecs.registry = reg;
    // 保留地图等级
    initWorld(map.currentLevel + 1);
    ecs.w.add(player.entity, damage);
    ecs.w.add(player.entity, health);
}

pub fn update(_: f32) void {
    if (window.isKeyRelease(.H)) isHelp = !isHelp;
    if (window.isKeyRelease(.X)) isDebug = !isDebug;

    if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
        return window.toggleFullScreen();
    }

    if (window.isKeyRelease(.M)) map.minMap = !map.minMap;

    switch (ecs.w.getContext(TurnState).?) {
        .over, .win => if (window.isKeyRelease(._1)) restart(),
        .player => player.update(),
        .monster => monster.update(),
        .next => nextLevel(),
    }
}

pub fn draw() void {
    camera.beginDraw(.{});
    defer camera.endDraw();

    window.keepAspectRatio();
    sceneCall("draw", .{});

    if (map.minMap) camera.mode = .local;
    map.draw();

    var view = ecs.w.view(.{ gfx.Texture, Position, PlayerView });
    while (view.next()) |entity| {
        const pos = view.get(entity, Position);
        camera.draw(view.get(entity, gfx.Texture), pos);
    }
    if (map.minMap) {
        camera.scale = .init(0.25, 0.25);
        camera.flushTexture();
        camera.scale = .init(1, 1);
        camera.mode = .world;
    }

    hud.draw();

    if (isHelp) drawHelpInfo() else if (isDebug) drawDebugInfo();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关掉
    ;
    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawColorText(text, .init(10, 5), .green);
}

var debutTextCount: u32 = 0;
fn drawDebugInfo() void {
    var buffer: [1024]u8 = undefined;
    const format =
        \\后端：{s}
        \\帧率：{}
        \\帧时：{d:.2}
        \\用时：{d:.2}
        \\显存：{}
        \\常量：{}
        \\绘制：{}
        \\图片：{}
        \\文字：{}
        \\内存：{}
        \\鼠标：{d:.2}，{d:.2}
        \\相机：{d:.2}，{d:.2}
    ;

    const stats = camera.queryFrameStats();
    const text = zhu.format(&buffer, format, .{
        @tagName(camera.queryBackend()),
        window.frameRate,
        window.frameDeltaPerSecond,
        window.usedDeltaPerSecond,
        stats.size_append_buffer + stats.size_update_buffer,
        stats.size_apply_uniforms,
        stats.num_draw,
        camera.imageDrawCount(),
        // Debug 信息本身的次数也应该统计进去
        camera.textDrawCount() + debutTextCount,
        window.countingAllocator.used,
        window.mousePosition.x,
        window.mousePosition.y,
        camera.position.x,
        camera.position.y,
    });

    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawColorText(text, .init(10, 5), .green);
}

pub fn deinit() void {
    sceneCall("deinit", .{});
    ecs.deinit();
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    _ = function;
    _ = args;
}
