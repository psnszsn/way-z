const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libxev = b.dependency("libxev", .{}).module("xev");

    const wayland = b.addModule("wayland", .{
        .root_source_file = b.path("./src/lib.zig"),
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

    inline for (.{ "globals", "seats", "hello", "kb_grab" }) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .root_source_file = b.path("examples/" ++ example ++ ".zig"),
            .target = target,
            .optimize = optimize,
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
}
