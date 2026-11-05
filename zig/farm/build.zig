const std = @import("std");

pub fn build(b: *std.Build) void {
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
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ecs", .module = migu.module("ecs") },
            .{ .name = "zhu", .module = zhuyu.module("zhu") },
        },
    });
    const exe = b.addExecutable(.{ .name = "demo", .root_module = mod });
    if (target.result.os.tag == .windows and optimize != .debug)
        exe.subsystem = .windows;
    b.installArtifact(exe);
    const tests = b.addTest(.{ .name = "tests", .root_module = mod });
    const runTests = b.addRunArtifact(tests);
    b.step("test", "Run farm tests").dependOn(&runTests.step);
    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    run.addPassthruArgs();
    b.step("run", "Run the app").dependOn(&run.step);
}
