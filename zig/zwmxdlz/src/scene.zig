const std = @import("std");
const window = @import("window.zig");
const gfx = @import("graphics.zig");
const audio = @import("zaudio");

const MenuScene = @import("scene/MenuScene.zig");
const GameScene = @import("scene/GameScene.zig");
const SelectorScene = @import("scene/SelectorScene.zig");

pub var currentScene: Scene = undefined;
pub var camera: Camera = .{};
pub var audioEngine: *audio.Engine = undefined;

pub var playerType1: PlayerType = .peaShooter;
pub var playerType2: PlayerType = .sunFlower;

var menuScene: MenuScene = undefined;
pub var gameScene: GameScene = undefined;
var selectorScene: SelectorScene = undefined;

pub const PlayerType = enum { peaShooter, sunFlower };

pub const Camera = struct {
    x: f32 = 0,
    y: f32 = 0,
};

pub const SceneType = enum { menu, game, selector };
pub const Scene = union(SceneType) {
    menu: *MenuScene,
    game: *GameScene,
    selector: *SelectorScene,

    pub fn enter(self: Scene) void {
        switch (self) {
            inline else => |s| s.enter(),
        }
    }

    pub fn exit(self: Scene) void {
        switch (self) {
            inline else => |s| s.exit(),
        }
    }

    pub fn event(self: Scene, ev: *const window.Event) void {
        switch (self) {
            inline else => |s| s.event(ev),
        }
    }

    pub fn update(self: Scene) void {
        switch (self) {
            inline else => |s| s.update(),
        }
    }

    pub fn render(self: Scene) void {
        switch (self) {
            inline else => |s| s.render(),
        }
    }
};

pub fn init() void {
    std.log.info("scene init", .{});

    audioEngine = audio.Engine.create(null) catch unreachable;
    menuScene = MenuScene.init();
    gameScene = GameScene.init();
    selectorScene = SelectorScene.init();
    currentScene = Scene{ .menu = &menuScene };

    currentScene.enter();
}

pub fn changeCurrentScene(sceneType: SceneType) void {
    currentScene.exit();
    currentScene = switch (sceneType) {
        .menu => Scene{ .menu = &menuScene },
        .game => Scene{ .game = &gameScene },
        .selector => Scene{ .selector = &selectorScene },
    };
    currentScene.enter();
}

pub fn deinit() void {
    std.log.info("scene deinit", .{});
    currentScene.exit();
    menuScene.deinit();
    selectorScene.deinit();
    gameScene.deinit();
    audioEngine.destroy();
}
