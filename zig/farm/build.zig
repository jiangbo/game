const std = @import("std");
const sk = @import("sokol");
const zhuBuild = @import("zhuyu");

const Options = struct {
    mod: *std.Build.Module,
    ecsModule: *std.Build.Module,
    emsdk: *std.Build.Dependency,
    zhuyu: *std.Build.Dependency,
    zhuModule: *std.Build.Module,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    const migu = b.dependency("migu", .{
        .target = target,
        .optimize = optimize,
    });
    const ecsModule = migu.module("ecs");
    const zhuyu = b.dependency("zhuyu", .{
        .target = target,
        .optimize = optimize,
    });
    const zhuModule = zhuyu.module("zhu");
    const emsdk = sokol.builder.dependency("emsdk", .{});
    const emsdkStep = sk.emSdkInstallStep(b, emsdk, .{});
    b.step("install-emsdk", "install emsdk").dependOn(emsdkStep);

    const exeModule = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ecs", .module = ecsModule },
            .{ .name = "zhu", .module = zhuModule },
        },
    });

    const options = Options{
        .mod = exeModule,
        .ecsModule = ecsModule,
        .emsdk = emsdk,
        .zhuyu = zhuyu,
        .zhuModule = zhuModule,
    };
    if (target.result.cpu.arch.isWasm()) {
        try buildWeb(b, options);
    } else {
        try buildNative(b, options);
    }
}

fn buildNative(b: *std.Build, options: Options) !void {
    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = options.mod,
    });

    const optimize = options.mod.optimize.?;
    const target = options.mod.resolved_target.?;
    if (optimize != .Debug) exe.subsystem = .Windows;

    b.installArtifact(exe);

    const testModule = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    testModule.addImport("zhu", options.zhuModule);
    testModule.addImport("ecs", options.ecsModule);

    const tests = b.addTest(.{ .name = "tests", .root_module = testModule });

    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run farm tests").dependOn(&run_tests.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    b.step("run", "Run the app").dependOn(&run_cmd.step);
}

fn buildWeb(b: *std.Build, options: Options) !void {
    const optimize = options.mod.optimize.?;
    const target = options.mod.resolved_target.?;

    const exe = b.addLibrary(.{
        .name = "demo",
        .root_module = options.mod,
    });

    const zhuArgs = try zhuBuild.webArgs(b, options.zhuyu);
    const extraArgs = try b.allocator.alloc([]const u8, 1 + zhuArgs.len);
    extraArgs[0] = "-sINITIAL_MEMORY=64MB";
    @memcpy(extraArgs[1..], zhuArgs);

    const link_step = try sk.emLinkStep(b, .{
        .lib_main = exe,
        .target = target,
        .optimize = optimize,
        .use_webgl2 = true,
        .emsdk = options.emsdk,
        .use_emmalloc = true,
        // TODO Zig 0.17 重新验证，能关闭就改回 false。
        // 当前先保持 Web 文件读写可用。
        .use_filesystem = true,
        .extra_args = extraArgs,
        .shell_file_path = b.path("index.html"),
    });

    // 将 Emscripten 链接输出接到默认安装步骤。
    b.getInstallStep().dependOn(&link_step.step);
}
