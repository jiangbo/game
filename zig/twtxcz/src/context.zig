const std = @import("std");
const gfx = @import("graphics.zig");

pub var allocator: std.mem.Allocator = undefined;
pub var rand: std.Random = undefined;
pub var width: f32 = 0;
pub var height: f32 = 0;
pub var title: [:0]const u8 = "游戏开发";
pub var clearColor: gfx.Color = .{ .r = 1, .b = 1, .a = 1 };

pub var camera: gfx.Camera = undefined;
pub var textureSampler: gfx.Sampler = undefined;
pub var batchBuffer: gfx.BatchBuffer = undefined;

pub var vertexBuffer: ?gfx.Buffer = undefined;
pub var indexBuffer: ?gfx.Buffer = undefined;
