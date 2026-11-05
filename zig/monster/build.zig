const std = @import("std");
const cimgui = @import("cimgui");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zhuyu = b.dependency("zhuyu", .{
        .target = target,
        .optimize = optimize,
        .imgui = true,
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
    const library = zhuyu.artifact("sokol_clib");
    library.root_module.addIncludePath(gui.path(config.include_dir));

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
