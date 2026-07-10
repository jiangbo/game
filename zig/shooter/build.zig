const std = @import("std");
const zhuBuild = @import("zhuyu");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zhuyu = b.dependency("zhuyu", .{
        .target = target,
        .optimize = optimize,
    });
    const zhuModule = zhuyu.module("zhu");

    const imports = [_]std.Build.Module.Import{
        .{ .name = "zhu", .module = zhuModule },
    };

    var emLink = zhuBuild.defaultEmLinkOptions;
    emLink.use_webgl2 = true;
    emLink.use_emmalloc = true;
    emLink.use_filesystem = true;
    emLink.shell_file_path = b.path("index.html");
    emLink.extra_args = &.{"-sINITIAL_MEMORY=64MB"};

    // Shooter 的入口仍然位于 src 目录。
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
