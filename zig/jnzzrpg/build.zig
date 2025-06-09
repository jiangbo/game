const std = @import("std");
const sk = @import("sokol");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    try if (target.result.cpu.arch.isWasm())
        buildWeb(b, target)
    else
        buildNative(b, target);
}

fn buildNative(b: *std.Build, target: std.Build.ResolvedTarget) !void {
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
    b.step("run", "Run the app").dependOn(&run_cmd.step);
}

fn buildWeb(b: *std.Build, target: std.Build.ResolvedTarget) !void {
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addStaticLibrary(.{
        .name = "demo",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });

    const sokol = b.dependency("sokol", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("sokol", sokol.module("sokol"));

    const emsdk = sokol.builder.dependency("emsdk", .{});
    const include = emsdk.path(b.pathJoin(&.{ "upstream", "emscripten", "cache", "sysroot", "include" }));
    exe.addSystemIncludePath(include);

    const writeFiles = b.addWriteFiles();
    exe.step.dependOn(&writeFiles.step);

    const stbAudioPath = writeFiles.add("stb_audio.c", stbAudioSource);
    exe.root_module.addCSourceFile(.{ .file = stbAudioPath, .flags = &.{ "-O2", "-fno-sanitize=undefined" } });

    const stb = b.dependency("stb", .{ .target = target, .optimize = optimize });
    exe.root_module.addIncludePath(stb.path("."));
    const stbImagePath = writeFiles.add("stb_image.c", stbImageSource);
    exe.root_module.addCSourceFile(.{ .file = stbImagePath, .flags = &.{ "-O2", "-fno-sanitize=undefined" } });

    const link_step = try sk.emLinkStep(b, .{
        .lib_main = exe,
        .target = target,
        .optimize = optimize,
        .emsdk = emsdk,
        .use_offset_converter = true,
        .use_webgl2 = true,
        .use_emmalloc = true,
        .use_filesystem = false,
        .shell_file_path = b.path("index.html"),
    });

    // attach Emscripten linker output to default install step
    b.getInstallStep().dependOn(&link_step.step);
}

const stbImageSource =
    \\
    \\#define STB_IMAGE_IMPLEMENTATION
    \\#define STBI_ONLY_PNG
    \\#define STBI_NO_STDIO
    \\#include "stb_image.h"
    \\
;

const stbAudioSource =
    \\
    \\#define STB_VORBIS_NO_PUSHDATA_API
    \\#define STB_VORBIS_NO_INTEGER_CONVERSION
    \\#define STB_VORBIS_NO_STDIO
    \\
    \\#include "stb_vorbis.c"
    \\
;
