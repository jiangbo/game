const ray = @cImport({
    @cInclude("raylib.h");
});
const std = @import("std");
const basic = @import("basic.zig");
const Rectangle = basic.Rectangle;
const Vector = basic.Vector;

var screenWidth: usize = 0;

pub fn init(width: usize, height: usize, title: [:0]const u8) void {
    ray.InitWindow(@intCast(width), @intCast(height), title);
    ray.SetTargetFPS(60);
    ray.SetExitKey(ray.KEY_NULL);
    screenWidth = width;
    ray.InitAudioDevice();
    return;
}

pub fn deinit() void {
    ray.CloseAudioDevice();
    ray.CloseWindow();
}

pub fn shouldContinue() bool {
    return !ray.WindowShouldClose();
}

pub fn beginDraw() void {
    ray.BeginDrawing();
    ray.ClearBackground(ray.WHITE);
}

pub fn endDraw() void {
    ray.DrawFPS(@intCast(screenWidth - 100), 10);
    ray.EndDrawing();
}

pub fn time() usize {
    return @intFromFloat(ray.GetTime() * 1000);
}

pub fn frameTime() usize {
    return @intFromFloat(ray.GetFrameTime() * 1000);
}

pub fn getPressed() usize {
    return @intCast(ray.GetKeyPressed());
}

pub fn isPressed(key: usize) bool {
    return ray.IsKeyPressed(@intCast(key));
}

pub fn isDown(key: usize) bool {
    return ray.IsKeyDown(@intCast(key));
}

pub fn random(min: usize, max: usize) usize {
    const minc: c_int = @intCast(min);
    const maxc: c_int = @intCast(max);
    return @intCast(ray.GetRandomValue(minc, maxc - 1));
}

pub fn isCollision(rec1: basic.Rectangle, rec2: basic.Rectangle) bool {
    return ray.CheckCollisionRecs(toRayRec(rec1), toRayRec(rec2));
}

pub const Texture = struct {
    width: usize,
    texture: ray.Texture2D,

    pub fn init(path: [:0]const u8) Texture {
        const texture = ray.LoadTexture(path);
        return .{ .texture = texture, .width = @intCast(texture.width) };
    }

    pub fn empty() Texture {
        return Texture{ .texture = ray.Texture2D{}, .width = 0 };
    }

    pub fn draw(self: Texture) void {
        ray.DrawTexture(self.texture, 0, 0, ray.WHITE);
    }

    pub fn drawXY(self: Texture, x: usize, y: usize) void {
        const vec = .{ .x = usizeToF32(x), .y = usizeToF32(y) };
        ray.DrawTextureV(self.texture, vec, ray.WHITE);
    }

    pub fn drawRec(self: Texture, rec: Rectangle, pos: Vector) void {
        const vec = .{ .x = usizeToF32(pos.x), .y = usizeToF32(pos.y) };
        ray.DrawTextureRec(self.texture, toRayRec(rec), vec, ray.WHITE);
    }

    pub fn deinit(self: Texture) void {
        ray.UnloadTexture(self.texture);
    }
};

fn toRayRec(rec: basic.Rectangle) ray.Rectangle {
    return ray.Rectangle{
        .x = usizeToF32(rec.x),
        .y = usizeToF32(rec.y),
        .width = usizeToF32(rec.width),
        .height = usizeToF32(rec.height),
    };
}

fn usizeToF32(value: usize) f32 {
    return @floatFromInt(value);
}

pub const Sound = struct {
    sound: ray.Sound,

    pub fn init(path: [:0]const u8) Sound {
        return .{ .sound = ray.LoadSound(path) };
    }

    pub fn play(self: Sound) void {
        ray.PlaySound(self.sound);
    }

    pub fn deinit(self: Sound) void {
        ray.UnloadSound(self.sound);
    }
};
