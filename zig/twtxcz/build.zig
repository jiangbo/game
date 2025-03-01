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

    exe.subsystem = .Windows;
    b.installArtifact(exe);

    const sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("sokol", sokol.module("sokol"));

    const zstbi = b.dependency("zstbi", .{});
    exe.root_module.addImport("stbi", zstbi.module("root"));
    exe.linkLibrary(zstbi.artifact("zstbi"));

    const zmath = b.dependency("zmath", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zmath", zmath.module("root"));

    const minimp3 = b.dependency("minimp3", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("mp3", minimp3.module("decoder"));

    // const sdl_dep = b.dependency("sdl", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .preferred_link_mode = .static,
    // });
    // const sdl_lib = sdl_dep.artifact("SDL3");
    // exe.linkLibrary(sdl_lib);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
