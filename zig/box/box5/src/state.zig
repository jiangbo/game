const std = @import("std");
const ray = @import("raylib.zig");
const stage = @import("stage.zig");
const SequenceType = stage.SequenceType;

pub const State = struct {
    current: Sequence,
    box: ray.Texture2D,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) State {
        return State{
            .current = Sequence{ .title = Title.init() },
            .box = ray.LoadTexture("data/image/box.dds"),
            .allocator = allocator,
        };
    }

    pub fn update(self: *State) void {
        const sequenceType = self.current.update() orelse return;

        const old = self.current;
        self.current = switch (sequenceType) {
            .title => Sequence{ .title = Title.init() },
            .stage => .{ .stage = stage.init(self.allocator, 1, self.box) orelse return },
        };
        old.deinit();
    }

    pub fn draw(self: State) void {
        self.current.draw();
    }

    pub fn deinit(self: State) void {
        self.current.deinit();
        ray.UnloadTexture(self.box);
    }
};

pub const Sequence = union(SequenceType) {
    title: Title,
    stage: stage.Stage,

    pub fn update(self: *Sequence) ?SequenceType {
        return switch (self.*) {
            inline else => |*case| case.update(),
        };
    }

    pub fn draw(self: Sequence) void {
        ray.BeginDrawing();
        defer ray.EndDrawing();
        defer ray.DrawFPS(235, 10);
        ray.ClearBackground(ray.WHITE);

        switch (self) {
            inline else => |sequence| sequence.draw(),
        }
    }

    pub fn deinit(self: Sequence) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }
};

const Title = struct {
    texture: ray.Texture2D,

    pub fn init() Title {
        return Title{ .texture = ray.LoadTexture("data/image/title.dds") };
    }

    pub fn update(_: Title) ?SequenceType {
        return if (ray.IsKeyPressed(ray.KEY_SPACE)) .stage else null;
    }

    pub fn draw(self: Title) void {
        ray.DrawTexture(self.texture, 0, 0, ray.WHITE);
    }

    pub fn deinit(self: Title) void {
        ray.UnloadTexture(self.texture);
    }
};
