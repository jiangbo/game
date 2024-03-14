const std = @import("std");
const engine = @import("engine.zig");
const stage = @import("stage.zig");

pub const State = struct {
    current: Sequence,
    box: engine.Texture,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) State {
        return State{
            .current = Sequence{ .title = Title.init() },
            .box = engine.Texture.init("box.dds"),
            .allocator = allocator,
        };
    }

    pub fn update(self: *State) void {
        const sequence = self.current.update() orelse return;

        const old = self.current;
        self.current = switch (sequence) {
            .title => .{ .title = Title.init() },
            .select => .{ .select = Select.init() },
            .none => .{ .none = None.init() },
            .stage => |level| label: {
                const s = stage.init(self.allocator, level, self.box);
                break :label if (s) |value|
                    .{ .stage = value }
                else
                    .{ .none = None.init() };
            },
        };
        old.deinit();
    }

    pub fn draw(self: State) void {
        self.current.draw();
    }

    pub fn deinit(self: State) void {
        self.current.deinit();
        self.box.deinit();
    }
};

const Sequence = union(stage.SequenceType) {
    title: Title,
    select: Select,
    stage: stage.Stage,
    none: None,

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

    fn deinit(self: Sequence) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }
};

const Title = struct {
    texture: engine.Texture,

    fn init() Title {
        return Title{ .texture = engine.Texture.init("title.dds") };
    }

    fn update(_: Title) ?stage.SequenceData {
        return if (engine.isPressed(engine.Key.space)) .select else null;
    }

    fn draw(self: Title) void {
        self.texture.draw();
    }

    fn deinit(self: Title) void {
        self.texture.deinit();
    }
};

const Select = struct {
    texture: engine.Texture,

    fn init() Select {
        return Select{ .texture = engine.Texture.init("select.dds") };
    }

    fn update(_: Select) ?stage.SequenceData {
        const char = engine.getPressed();
        return if (char >= '1' and char <= '9')
            .{ .stage = char - '1' + 1 }
        else
            null;
    }

    fn draw(self: Select) void {
        self.texture.draw();
    }

    fn deinit(self: Select) void {
        self.texture.deinit();
    }
};

const None = struct {
    text: [:0]const u8,

    fn init() None {
        return None{ .text = "STAGE LOAD ERROR" };
    }

    fn update(_: None) ?stage.SequenceData {
        return if (engine.isPressed(engine.Key.space)) .select else null;
    }

    fn draw(self: None) void {
        engine.clear(0x39918EFF);
        engine.drawText(40, 100, self.text);
    }

    fn deinit(_: None) void {}
};
