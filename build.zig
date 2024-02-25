const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // const optimize = std.builtin.OptimizeMode.ReleaseFast;

    // Configure executable
    const exe = b.addExecutable(.{
        .name = "particles_zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add GLFW
    const glfw_dep = b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("glfw", glfw_dep.module("mach-glfw"));
    @import("mach_glfw").addPaths(exe);

    // Add OpenGL
    exe.root_module.addImport("gl", b.createModule(.{
        .root_source_file = .{ .path = "libs/gl46.zig" },
    }));

    // Create install step
    b.installArtifact(exe);

    // Add run step so 'zig build run' executes program after building
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Similar to the above, adds tests and a test step 'zig build test'
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
