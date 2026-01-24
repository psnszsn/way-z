const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const way_z = b.dependency("way-z", .{});

    const exe = b.addExecutable(.{
        .name = "fontviewer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("fontviewer.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = false,
    });

    exe.root_module.addImport("wayland", way_z.module("wayland"));
    exe.root_module.addImport("toolkit", way_z.module("toolkit"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
