const std = @import("std");
const popup = @import("popup.zig");
const play = @import("play.zig");

const Texture = @import("engine.zig").Texture;
pub const SequenceType = enum { title, select, stage, none };
pub const SequenceData = union(SequenceType) {
    title: void,
    select: void,
    stage: usize,
    none: void,
};

pub fn init(allocator: std.mem.Allocator, level: usize, box: Texture) ?Stage {
    return Stage{
        .level = level,
        .current = play.init(allocator, level, box) orelse return null,
        .popup = .{ .loading = popup.Loading.init() },
    };
}

pub const Stage = struct {
    level: usize,
    current: play.Play,
    popup: ?popup.Popup = null,

    pub fn update(self: *Stage) ?SequenceData {
        if (self.popup) |*option| {
            const menu = option.update() orelse return null;
            defer option.deinit();
            switch (menu) {
                .title => return .title,
                .select => return .select,
                .reset => return .{ .stage = self.level },
                .next => return .{ .stage = self.level + 1 },
                .quit => self.popup = null,
            }
        }

        self.popup = switch (self.current.update() orelse return null) {
            .clear => .{ .clear = popup.Clear.init() },
            .menu => .{ .menu = popup.Menu.init() },
            .loading => .{ .loading = popup.Loading.init() },
        };

        return null;
    }

    pub fn draw(self: Stage) void {
        self.current.draw();
        if (self.popup) |option| option.draw();
    }

    pub fn deinit(self: Stage) void {
        if (self.popup) |option| option.deinit();
        self.current.deinit();
    }
};
