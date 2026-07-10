const std = @import("std");
const zhuBuild = @import("zhuyu");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zhuyu = b.dependency("zhuyu", .{
        .target = target,
        .optimize = optimize,
    });
    const migu = b.dependency("migu", .{
        .target = target,
        .optimize = optimize,
    });

    const imports = [_]std.Build.Module.Import{
        .{ .name = "ecs", .module = migu.module("ecs") },
        .{ .name = "zhu", .module = zhuyu.module("zhu") },
    };

    var emLink = zhuBuild.defaultEmLinkOptions;
    emLink.use_webgl2 = true;
    emLink.use_emmalloc = true;
    emLink.use_filesystem = true;
    emLink.extra_args = &.{"-sINITIAL_MEMORY=64MB"};

    _ = try zhuBuild.addApp(b, .{
        .name = "demo",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .zhuyu = zhuyu,
        .imports = &imports,
        .em_link = emLink,
    });
}
