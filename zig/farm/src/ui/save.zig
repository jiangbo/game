const std = @import("std");
const zhu = @import("zhu");

const storage = @import("../storage.zig");
const menus: []const zhu.widget.Menu = @import("save.zon");

pub const Mode = enum { load, save };
pub const Request = union(enum) { close, save: u8, load: u8 };
pub const Slot = storage.Slot;

var mode: Mode = .load;
var records: []const Slot = &.{};
var disabledBuffer: [menus[0].buttons.len]usize = undefined;
var disabled: std.ArrayList(usize) = .initBuffer(&disabledBuffer);
var menu: zhu.widget.Menu = menus[0];

pub fn init(records_: []const Slot) void {
    records = records_;
    menu.centerInWindow();
    popup.popupMenu.centerInWindow();
}

pub fn open(next: Mode) void {
    mode = next;
    popup.slot = null;

    menu.disabled = &.{};
    switch (mode) {
        .load => load.open(),
        .save => menu.title.text = "Save Game",
    }
}

pub fn update() ?Request {
    if (popup.slot != null) {
        if (popup.update()) |slot| return .{ .save = slot };
        return null;
    }

    if (menu.update(.{})) |event| {
        if (event == records.len) return .close;

        return switch (mode) {
            .load => .{ .load = @intCast(event) },
            .save => save.choose(event),
        };
    }
    return null;
}

pub fn draw() void {
    menu.draw();
    for (0..records.len) |index| drawSlot(index);
    popup.draw();
}

fn drawSlot(index: usize) void {
    var buffer: [56]u8 = undefined;
    const label = switch (records[index]) {
        .empty => zhu.format(&buffer, "Slot {d} Empty", .{index + 1}),
        .valid => |summary| zhu.format(&buffer, "Slot {d} Day {d}", .{
            index + 1,
            summary.day,
        }),
    };

    menu.drawText(index, label);
}

const load = struct {
    fn open() void {
        disabled.clearRetainingCapacity();
        for (0..records.len) |index| switch (records[index]) {
            .valid => {},
            .empty => disabled.appendAssumeCapacity(index),
        };
        menu.disabled = disabled.items;
        menu.title.text = "Load Game";
    }
};

const save = struct {
    fn choose(slot: usize) ?Request {
        switch (records[slot]) {
            .empty => return .{ .save = @intCast(slot) },
            .valid => popup.slot = @intCast(slot),
        }
        return null;
    }
};

const popup = struct {
    var slot: ?u8 = null;
    var popupMenu: zhu.widget.Menu = menus[1];

    fn update() ?u8 {
        const current = slot orelse return null;

        if (popupMenu.update(.{})) |event| {
            slot = null;
            if (event == 0) return current;
            if (event == 1) return null;
            unreachable;
        }
        return null;
    }

    fn draw() void {
        const current = slot orelse return;

        var buffer: [40]u8 = undefined;
        var copy = popupMenu;
        const fmt = "Overwrite slot {d}?";
        copy.title.text = zhu.format(&buffer, fmt, .{current + 1});
        copy.draw();
    }
};
