const std = @import("std");
const ray = @import("raylib.zig");

pub fn init(width: usize, height: usize, title: [:0]const u8) void {
    ray.InitWindow(@intCast(width), @intCast(height), title);
    ray.SetTargetFPS(60);
    ray.SetExitKey(ray.KEY_NULL);
}

pub fn shoudContinue() bool {
    return !ray.WindowShouldClose();
}

pub fn beginDraw() void {
    ray.BeginDrawing();
    ray.ClearBackground(ray.WHITE);
}

pub fn drawText(x: usize, y: usize, text: [:0]const u8) void {
    ray.DrawText(text, @intCast(x), @intCast(y), 24, ray.RED);
}

pub fn clear(color: u32) void {
    ray.ClearBackground(ray.GetColor(color));
}

pub fn endDraw() void {
    ray.DrawFPS(235, 10);
    ray.EndDrawing();
}

pub fn getPressed() usize {
    return @intCast(ray.GetKeyPressed());
}

pub fn isPressed(key: usize) bool {
    return ray.IsKeyPressed(@intCast(key));
}

pub fn time() usize {
    return @intFromFloat(ray.GetTime() * 1000);
}

pub fn deinit() void {
    ray.CloseWindow();
}

const maxPathLength = 30;

pub fn readStageText(allocator: std.mem.Allocator, level: usize) ![]const u8 {
    var buf: [maxPathLength]u8 = undefined;
    const path = try std.fmt.bufPrint(&buf, "data/stage/{}.txt", .{level});

    std.log.info("load stage: {s}", .{path});
    return try readAll(allocator, path);
}

fn readAll(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

pub const Vector = struct {
    x: usize = 0,
    y: usize = 0,

    fn toRay(self: Vector) ray.Vector2 {
        return ray.Vector2{
            .x = @floatFromInt(self.x),
            .y = @floatFromInt(self.y),
        };
    }
};

pub const Rectangle = struct {
    x: usize = 0,
    y: usize = 0,
    width: usize = 0,
    height: usize = 0,

    fn toRay(self: Rectangle) ray.Rectangle {
        return ray.Rectangle{
            .x = @floatFromInt(self.x),
            .y = @floatFromInt(self.y),
            .width = @floatFromInt(self.width),
            .height = @floatFromInt(self.height),
        };
    }
};

pub const Texture = struct {
    texture: ray.Texture2D,

    pub fn init(name: []const u8) Texture {
        var buf: [maxPathLength]u8 = undefined;
        const format = "data/image/{s}";
        const path = std.fmt.bufPrintZ(&buf, format, .{name}) catch |e| {
            std.log.err("load image error: {}", .{e});
            return Texture{ .texture = ray.Texture2D{} };
        };

        return Texture{ .texture = ray.LoadTexture(path) };
    }

    pub fn draw(self: Texture) void {
        ray.DrawTexture(self.texture, 0, 0, ray.WHITE);
    }

    pub fn drawRectangle(self: Texture, rec: Rectangle, pos: Vector) void {
        ray.DrawTextureRec(self.texture, rec.toRay(), pos.toRay(), ray.WHITE);
    }

    pub fn deinit(self: Texture) void {
        ray.UnloadTexture(self.texture);
    }
};

pub const Key = struct {
    pub const @"null": usize = 0;
    pub const apostrophe: usize = 39;
    pub const comma: usize = 44;
    pub const minus: usize = 45;
    pub const period: usize = 46;
    pub const slash: usize = 47;
    pub const zero: usize = 48;
    pub const one: usize = 49;
    pub const two: usize = 50;
    pub const three: usize = 51;
    pub const four: usize = 52;
    pub const five: usize = 53;
    pub const six: usize = 54;
    pub const seven: usize = 55;
    pub const eight: usize = 56;
    pub const nine: usize = 57;
    pub const semicolon: usize = 59;
    pub const equal: usize = 61;
    pub const a: usize = 65;
    pub const b: usize = 66;
    pub const c: usize = 67;
    pub const d: usize = 68;
    pub const e: usize = 69;
    pub const f: usize = 70;
    pub const g: usize = 71;
    pub const h: usize = 72;
    pub const i: usize = 73;
    pub const j: usize = 74;
    pub const k: usize = 75;
    pub const l: usize = 76;
    pub const m: usize = 77;
    pub const n: usize = 78;
    pub const o: usize = 79;
    pub const p: usize = 80;
    pub const q: usize = 81;
    pub const r: usize = 82;
    pub const s: usize = 83;
    pub const t: usize = 84;
    pub const u: usize = 85;
    pub const v: usize = 86;
    pub const w: usize = 87;
    pub const x: usize = 88;
    pub const y: usize = 89;
    pub const z: usize = 90;
    pub const space: usize = 32;
    pub const right: usize = 262;
    pub const left: usize = 263;
    pub const down: usize = 264;
    pub const up: usize = 265;
};
