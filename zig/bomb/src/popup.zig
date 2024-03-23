const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

pub const MenuType = enum { quit, title, reset, next };
pub const PopupType = enum { clear, over, ending };

pub const Popup = union(PopupType) {
    clear: TimePopup,
    over: TimePopup,
    ending: TimePopup,

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

pub fn initWithType(popupType: PopupType) Popup {
    return switch (popupType) {
        .clear => .{ .clear = TimePopup.init("clear.png", .next) },
        .over => .{ .over = TimePopup.init("over.png", .title) },
        .ending => .{ .ending = TimePopup.init("ending.png", .title) },
    };
}

const TimePopup = struct {
    image: engine.Image,
    time: usize,
    target: MenuType,

    fn init(name: []const u8, target: MenuType) TimePopup {
        return TimePopup{
            .image = engine.Image.init(name),
            .time = engine.time(),
            .target = target,
        };
    }

    fn update(self: TimePopup) ?MenuType {
        return if (engine.time() - self.time > 2000) self.target else null;
    }

    fn draw(self: TimePopup) void {
        self.image.draw();
    }

    fn deinit(self: TimePopup) void {
        self.image.deinit();
    }
};
