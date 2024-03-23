const std = @import("std");
const engine = @import("engine.zig");
const stage = @import("stage.zig");

pub const State = struct {
    current: Sequence,
    mode: bool = false,

    pub fn init() State {
        return State{ .current = Sequence{ .title = Title.init() } };
    }

    pub fn update(self: *State) void {
        const sequence = self.current.update() orelse return;

        var old = self.current;
        self.current = switch (sequence) {
            .title => .{ .title = Title.init() },
            .mode => |mode| label: {
                self.mode = mode;
                break :label .{ .mode = Mode{} };
            },
            .stage => |level| label: {
                const s = stage.init(self.mode, level);
                break :label .{ .stage = s orelse return };
            },
        };
        old.deinit();
    }

    pub fn draw(self: State) void {
        self.current.draw();
    }

    pub fn deinit(self: *State) void {
        self.current.deinit();
    }
};

const Sequence = union(stage.SequenceType) {
    title: Title,
    mode: Mode,
    stage: stage.Stage,

    fn update(self: *Sequence) ?stage.SequenceData {
        return switch (self.*) {
            inline else => |*case| case.update(),
        };
    }

    fn draw(self: Sequence) void {
        engine.beginDraw();
        defer engine.endDraw();

        switch (self) {
            inline else => |sequence| sequence.draw(),
        }
    }

    fn deinit(self: *Sequence) void {
        switch (self.*) {
            inline else => |*case| case.deinit(),
        }
    }
};

const Title = struct {
    title: engine.Image,
    cursor: engine.Image,
    towPlayer: bool = false,

    fn init() Title {
        return Title{
            .title = engine.Image.init("title.png"),
            .cursor = engine.Image.init("cursor.png"),
        };
    }

    fn update(self: *Title) ?stage.SequenceData {
        if (engine.isPressed(engine.Key.w) or engine.isPressed(engine.Key.s)) {
            self.towPlayer = !self.towPlayer;
        }

        const result = stage.SequenceData{ .mode = self.towPlayer };
        return if (engine.isPressed(engine.Key.space)) result else null;
    }

    fn draw(self: Title) void {
        self.title.draw();
        self.cursor.drawXY(220, if (self.towPlayer) 433 else 395);
    }

    fn deinit(self: Title) void {
        self.title.deinit();
        self.cursor.deinit();
    }
};

const Mode = struct {
    fn update(_: Mode) ?stage.SequenceData {
        return .{ .stage = 0 };
    }

    fn draw(_: Mode) void {}

    fn deinit(_: Mode) void {}
};
