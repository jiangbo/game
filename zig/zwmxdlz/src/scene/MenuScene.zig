const std = @import("std");
const audio = @import("zaudio");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");
const MenuScene = @This();

background: gfx.Texture,
bgm: *audio.Sound,
confirm: *audio.Sound,

pub fn init() MenuScene {
    std.log.info("menu scene init", .{});

    var self: MenuScene = undefined;
    self.bgm = scene.audioEngine.createSoundFromFile(
        "assets/bgm_menu.mp3",
        .{ .flags = .{ .stream = true, .looping = true } },
    ) catch unreachable;

    self.confirm = scene.audioEngine.createSoundFromFile(
        "assets/ui_confirm.wav",
        .{},
    ) catch unreachable;

    self.background = gfx.loadTexture("assets/menu_background.png").?;
    return self;
}

pub fn enter(self: *MenuScene) void {
    std.log.info("menu scene enter", .{});
    self.bgm.start() catch unreachable;
}

pub fn exit(self: *MenuScene) void {
    std.log.info("menu scene exit", .{});
    self.bgm.stop() catch unreachable;
}

pub fn event(self: *MenuScene, ev: *const window.Event) void {
    if (ev.type == .KEY_UP) {
        self.confirm.start() catch unreachable;
        scene.changeCurrentScene(.selector);
    }
}

pub fn update(self: *MenuScene) void {
    _ = self;
}

pub fn render(self: *MenuScene) void {
    gfx.draw(0, 0, self.background);
}

pub fn deinit(self: *MenuScene) void {
    std.log.info("menu scene deinit", .{});

    self.bgm.destroy();
    self.confirm.destroy();
}
