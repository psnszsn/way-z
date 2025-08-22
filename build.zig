const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libxev = b.dependency("libxev", .{}).module("xev");

    const wayland = b.addModule("wayland", .{
        .root_source_file = b.path("./wayland/lib.zig"),
        .imports = &.{
            .{ .name = "xev", .module = libxev },
        },
    });

    const toolkit = b.addModule("toolkit", .{
        .root_source_file = b.path("./toolkit/toolkit.zig"),
        .imports = &.{
            .{ .name = "xev", .module = libxev },
            .{ .name = "wayland", .module = wayland },
        },
    });
    _ = toolkit; // autofix

    inline for (.{ "globals", "seats", "hello", "kb_grab", "animation" }) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .root_module = b.createModule(.{
                .root_source_file = b.path("wayland/examples/" ++ example ++ ".zig"),
                .target = target,
                .optimize = optimize,
            }),
            .use_llvm = true,
        });

        exe.root_module.addImport("wayland", wayland);
        exe.root_module.addImport("xev", libxev);
        // exe.use_lld = false;
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
    {
        const unit_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("wayland/lib.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        unit_tests.root_module.addImport("wayland", wayland);
        unit_tests.root_module.addImport("xev", libxev);

        const run_unit_tests = b.addRunArtifact(unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_unit_tests.step);
    }
}
