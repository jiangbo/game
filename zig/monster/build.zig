const std = @import("std");
const cimgui = @import("cimgui");

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

    const config = cimgui.getConfig(false);
    const gui = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });
    const sokol = zhuyu.builder.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .gles3 = false,
        .egl = false,
    });
    const library = sokol.artifact("sokol_clib");
    library.root_module.addIncludePath(gui.path(config.include_dir));
    const backend = switch (target.result.os.tag) {
        .windows => "-DSOKOL_D3D11",
        .macos, .ios => "-DSOKOL_METAL",
        .emscripten => "-DSOKOL_GLES3",
        else => "-DSOKOL_GLCORE",
    };
    library.root_module.addCSourceFile(.{
        .file = sokol.path("src/sokol/c/sokol_imgui.c"),
        .flags = &.{ "-DIMPL", backend },
    });

    const module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cimgui", .module = gui.module(config.module_name) },
            .{ .name = "ecs", .module = migu.module("ecs") },
            .{ .name = "zhu", .module = zhuyu.module("zhu") },
        },
    });

    const exe = b.addExecutable(.{ .name = "demo", .root_module = module });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();
    b.step("run", "Run the game").dependOn(&run.step);
}
