const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libxev = b.dependency("libxev", .{}).module("xev");

    const wayland = b.createModule(.{
        .root_source_file = .{ .path = "./src/lib.zig" },
        .imports = &.{
            .{ .name = "xev", .module = libxev },
        },
    });

    {
        // const unit_tests = b.addTest(.{
        //     .root_source_file = .{ .path = "src/main.zig" },
        //     .target = target,
        //     .optimize = optimize,
        // });
        // unit_tests.addModule("libcoro", libcoro);
        // const run_unit_tests = b.addRunArtifact(unit_tests);
        //
        // const test_step = b.step("test", "Run unit tests");
        // test_step.dependOn(&run_unit_tests.step);

        // const installDocs = b.addInstallDirectory(.{
        //     .source_dir = exe.getEmittedDocs(),
        //     .install_dir = .prefix,
        //     .install_subdir = "docs",
        // });
        //
        // const docsStep = b.step("docs", "Generate documentation");
        // docsStep.dependOn(&installDocs.step);
    }

    inline for (.{ "globals", "seats", "hello", "bar" }) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .root_source_file = .{ .path = "examples/" ++ example ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });

        exe.root_module.addImport("wayland", wayland);
        exe.root_module.addImport("xev", libxev);
        // exe.linkLibC();

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        // run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run-" ++ example, "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
