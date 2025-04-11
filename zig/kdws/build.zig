const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (optimize != .Debug) exe.subsystem = .Windows;

    b.installArtifact(exe);

    const sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("sokol", sokol.module("sokol"));

    const writeFiles = b.addWriteFiles();
    exe.step.dependOn(&writeFiles.step);

    const stb = b.dependency("stb", .{ .target = target, .optimize = optimize });
    exe.root_module.addIncludePath(stb.path("."));
    const stbImagePath = writeFiles.add("stb_image.c", stbImageSource);
    exe.root_module.addCSourceFile(.{ .file = stbImagePath, .flags = &.{"-O2"} });

    const stbAudioPath = writeFiles.add("stb_audio.c", stbAudioSource);
    exe.root_module.addCSourceFile(.{ .file = stbAudioPath, .flags = &.{"-O2"} });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

const stbImageSource =
    \\
    \\#define STB_IMAGE_IMPLEMENTATION
    \\#define STBI_ONLY_PNG
    \\#include "stb_image.h"
    \\
;

const stbAudioSource =
    \\
    \\#define STB_VORBIS_NO_PUSHDATA_API
    \\#define STB_VORBIS_NO_INTEGER_CONVERSION
    \\
    \\#include "stb_vorbis.c"
    \\
;
