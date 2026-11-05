const ecs = @import("ecs");
const std = @import("std");
const zhu = @import("zhu");

const map = @import("map.zig");
const gui = @import("gui.zig");
const scene = @import("scene.zig");
const hud = @import("hud.zig");
const title = @import("title.zig");
const ctx = @import("context.zig");

var commandBuffer: [128]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;
const atlas: zhu.Atlas = @import("zon/atlas.zon");
const fontZon: zhu.text.static.Font = @import("zon/font.zon");

var registry: ecs.World = undefined;
var battleLoaded: bool = false;

pub fn init(allocator: zhu.Allocator) void {
    zhu.audio.init(&soundBuffer, .{ .sample_rate = 22050 });
    zhu.loadAtlas(atlas, .nearest);
    zhu.batch.init(&commandBuffer);
    const whiteCircle = zhu.getImage("circle.png").?;
    const area: zhu.Rect = .init(.xy(16, 16), .xy(32, 32));
    zhu.batch.whiteImage = whiteCircle.sub(area);
    zhu.text.init(fontZon, .{ .size = 32 });
    registry = .init(allocator);

    gui.init();
    ctx.init(allocator);
    scene.init();
    hud.init();
    title.init();
    title.enter(allocator);
}

pub fn event(ev: *const zhu.window.Event) void {
    gui.event(ev);
}

pub fn frame(delta: f32) void {
    if (ctx.pendingScene) |s| {
        switchScene(registry.allocator, s);
    }
    switch (ctx.currentScene) {
        .battle => {
            const scaled = delta * ctx.timeScale;
            gui.update(&registry, scaled);
            ctx.update(scaled);
            scene.update(&registry, scaled);
            hud.update(delta);

            zhu.batch.beginDraw();
            zhu.batch.useTarget(map.backgroundColor(), .{});
            scene.draw(&registry);
            hud.draw();
        },
        .title => {
            gui.update(&registry, delta);
            title.update(delta);

            zhu.batch.beginDraw();
            zhu.batch.useTarget(map.backgroundColor(), .{});
            title.draw();
        },
        .clear, .end => {
            gui.update(&registry, delta);
            zhu.batch.beginDraw();
            zhu.batch.useTarget(map.backgroundColor(), .{});
            if (battleLoaded) {
                scene.draw(&registry);
                hud.draw();
            }
        },
    }
    zhu.sokol.imgui.flush();
    zhu.batch.flush();
    gui.draw(&registry);
    zhu.batch.endDraw();
}

pub fn deinit(allocator: zhu.Allocator) void {
    scene.deinit(allocator);
    hud.deinit();
    title.deinit(allocator);
    ctx.deinit(allocator);
    gui.deinit();
    registry.deinit();
    zhu.audio.deinit();
}

fn switchScene(allocator: zhu.Allocator, s: ctx.SceneState) void {
    const previous = ctx.currentScene;
    const pushBattleOverlay = previous == .battle and (s == .clear or s == .end);

    ctx.pendingScene = null;

    if (!pushBattleOverlay) {
        if (battleLoaded) {
            scene.exit(allocator);
            battleLoaded = false;
        }
        if (previous == .title) title.exit(allocator);
        ctx.hoveredEntity = null;
        ctx.selectedEntity = null;
        registry.reset();
    }

    ctx.currentScene = s;
    switch (s) {
        .battle => {
            scene.enter(allocator);
            battleLoaded = true;
            hud.arrangeUnits();
        },
        .title => {
            title.enter(allocator);
        },
        .clear => {
            zhu.audio.playMusic("audio/level-win.ogg");
        },
        .end => {
            if (ctx.win) {
                zhu.audio.playMusic("audio/level-win.ogg");
            } else {
                zhu.audio.playMusic("audio/violin-lose-4.ogg");
            }
        },
    }
}

pub fn main(info: std.process.Init) void {
    zhu.init(info);
    zhu.extend.storage.init(info, "monster");
    zhu.window.run("怪物战争", .xy(1200, 912), .{
        .logicSize = .xy(1600, 1216),
        .scaleEnum = .fit,
    });
}
