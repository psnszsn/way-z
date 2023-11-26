const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libcoro = b.dependency("zigcoro", .{}).module("libcoro");

    {
        const exe = b.addExecutable(.{
            .name = "zoinx",
            .root_source_file = .{ .path = "src/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("libcoro", libcoro);
        exe.linkLibC();

        b.installArtifact(exe);
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        const unit_tests = b.addTest(.{
            .root_source_file = .{ .path = "src/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_unit_tests.step);
    }

    const wayland = b.createModule(.{
        .source_file = .{ .path = "./src/lib.zig" },
        .dependencies = &.{.{ .name = "libcoro", .module = libcoro }},
    });

    inline for (.{"globals"}) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .root_source_file = .{ .path = "examples/" ++ example ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });

        exe.addModule("wayland", wayland);
        exe.linkLibC();

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step("run-" ++ example, "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
