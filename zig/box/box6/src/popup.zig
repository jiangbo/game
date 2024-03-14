const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

pub const MenuType = enum { quit, title, select, reset, next };
pub const PopupType = enum { loading, menu, clear };

pub const Popup = union(PopupType) {
    loading: Loading,
    menu: Menu,
    clear: Clear,

    pub fn update(self: *Popup) ?MenuType {
        return switch (self.*) {
            inline else => |*case| case.update(),
        };
    }

    pub fn draw(self: Popup) void {
        switch (self) {
            inline else => |sequence| sequence.draw(),
        }
    }

    pub fn deinit(self: Popup) void {
        switch (self) {
            inline else => |sequence| sequence.deinit(),
        }
    }
};

pub const Loading = struct {
    texture: engine.Texture,
    time: usize,

    pub fn init() Loading {
        return Loading{
            .texture = engine.Texture.init("loading.dds"),
            .time = engine.time(),
        };
    }

    fn update(self: Loading) ?MenuType {
        return if (engine.time() - self.time > 1000) return .quit else null;
    }

    fn draw(self: Loading) void {
        self.texture.draw();
    }

    fn deinit(self: Loading) void {
        self.texture.deinit();
    }
};

pub const Menu = struct {
    texture: engine.Texture,

    pub fn init() Menu {
        return Menu{ .texture = engine.Texture.init("menu.dds") };
    }

    fn update(_: Menu) ?MenuType {
        const char = engine.getPressed();
        return switch (char) {
            '1' => .reset,
            '2' => .select,
            '3' => .title,
            '4' => .quit,
            else => null,
        };
    }

    fn draw(self: Menu) void {
        self.texture.draw();
    }

    fn deinit(self: Menu) void {
        self.texture.deinit();
    }
};

pub const Clear = struct {
    texture: engine.Texture,
    time: usize,

    pub fn init() Clear {
        return Clear{
            .texture = engine.Texture.init("clear.dds"),
            .time = engine.time(),
        };
    }

    fn update(self: Clear) ?MenuType {
        return if ((engine.time() - self.time) > 1) return .next else null;
    }

    fn draw(self: Clear) void {
        self.texture.draw();
    }

    fn deinit(self: Clear) void {
        self.texture.deinit();
    }
};
