const std = @import("std");
const popup = @import("popup.zig");
const play = @import("play.zig");

pub const SequenceType = enum { title, mode, stage };
pub const SequenceData = union(SequenceType) {
    title: void,
    mode: bool,
    stage: usize,
};

pub fn init(mode: bool, level: usize) ?Stage {
    const gameplay = play.Gameplay.init(mode, level) orelse return null;
    return Stage{ .level = level, .gameplay = gameplay };
}

const maxLevel = 3;
pub const Stage = struct {
    level: usize,
    gameplay: play.Gameplay,
    popup: ?popup.Popup = null,

    pub fn update(self: *Stage) ?SequenceData {
        if (self.popup) |*option| {
            const menu = option.update() orelse return null;
            defer option.deinit();
            switch (menu) {
                .title => return .title,
                .reset => return .{ .stage = self.level },
                .next => return .{ .stage = self.level + 1 },
                .quit => self.popup = null,
            }
        }

        const popupType = self.gameplay.update() orelse return null;

        if (popupType == .clear and self.level + 1 == maxLevel)
            self.popup = popup.initWithType(.ending)
        else
            self.popup = popup.initWithType(popupType);

        return null;
    }

    pub fn draw(self: Stage) void {
        self.gameplay.draw();
        if (self.popup) |option| option.draw();
    }

    pub fn deinit(self: *Stage) void {
        if (self.popup) |option| option.deinit();
        self.gameplay.deinit();
    }
};
