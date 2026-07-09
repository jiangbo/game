const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const input = @import("input.zig");
const inventory = @import("ui/inventory.zig");
const notice = @import("ui/notice.zig");
const rest = @import("ui/rest.zig");
const time = @import("ui/time.zig");
const pause = @import("ui/pause.zig");
const save = @import("ui/save.zig");

const Config = @import("storage.zig").Config;

pub const Message = struct { text: []const u8, fail: bool };
pub const Request = union(enum) {
    block,
    title,
    save: u8,
    load: u8,
};
const Popup = enum { save, rest, pause };

var activePopup: ?Popup = null;
var popupMessage: ?Message = null;

pub const Init = struct {
    slots: []const save.Slot,
    config: *Config,
};

pub fn init(args: Init) void {
    inventory.reset();
    notice.init();
    time.init();
    pause.cfg = args.config;
    save.init(args.slots);
    rest.init();
}

pub fn deinit() void {}

pub fn resetInventory() void {
    inventory.reset();
}

pub fn openPause() void {
    pause.open(.play);
    activePopup = .pause;
}

pub fn openRest() void {
    rest.hours = 8;
    activePopup = .rest;
}

pub fn update(world: *ecs.World, delta: f32) ?Request {
    notice.update(world, delta);

    if (activePopup) |active| {
        if (updatePopup(world, active)) |req| return req;
        return .block;
    }

    if (input.pressed(.pause)) {
        openPause();
        return .block;
    }

    inventory.update(world);
    return null;
}

fn updatePopup(world: *ecs.World, active: Popup) ?Request {
    switch (active) {
        .save => {
            if (save.update()) |result| {
                switch (result) {
                    .close => close(),
                    .save => |slot| {
                        activePopup = .pause;
                        return .{ .save = slot };
                    },
                    .load => |slot| {
                        activePopup = .pause;
                        return .{ .load = slot };
                    },
                }
            }
        },
        .rest => if (rest.update(world)) close(),
        .pause => if (pause.update()) |req| switch (req) {
            .close => close(),
            .save => {
                popupMessage = null;
                save.open(.save);
                activePopup = .save;
            },
            .load => {
                popupMessage = null;
                save.open(.load);
                activePopup = .save;
            },
            .title => return .title,
        },
    }
    return null;
}

pub fn showMessage(next: Message) void {
    popupMessage = next;
}

pub fn close() void {
    activePopup = null;
    popupMessage = null;
}

pub fn draw(world: *ecs.World) void {
    time.draw(world);
    inventory.draw(world);

    if (activePopup) |active| {
        switch (active) {
            .save => save.draw(),
            .rest => rest.draw(),
            .pause => pause.draw(),
        }
    }

    if (popupMessage) |current| {
        var color = zhu.Color.rgb(0.25, 1.0, 0.25);
        if (current.fail) color = .rgb(1.0, 0.25, 0.25);
        zhu.text.draw(current.text, .xy(zhu.window.size.x * 0.5, 32), .{
            .anchor = .center,
            .color = color,
        });
    }

    notice.draw(world);
}
