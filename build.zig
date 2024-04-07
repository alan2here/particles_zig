const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // const optimize = std.builtin.OptimizeMode.ReleaseFast;
    const root = .{ .path = "src/main.zig" };

    const exe = b.addExecutable(.{
        .name = "particles_zig",
        .root_source_file = root,
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_source_file = root,
        .target = target,
        .optimize = optimize,
    });

    const options = .{
        .target = target,
        .optimize = optimize,
    };

    const gl = b.createModule(.{
        .root_source_file = .{ .path = "libs/gl46.zig" },
    });
    const glfw = b.dependency("mach_glfw", options);
    const zmath = b.dependency("zmath", options);
    const znoise = b.dependency("znoise", options);

    inline for (.{ exe, tests }) |step| {
        step.root_module.addImport("glfw", glfw.module("mach-glfw"));
        step.root_module.addImport("gl", gl);
        step.root_module.addImport("zmath", zmath.module("root"));
        step.root_module.addImport("znoise", znoise.module("root"));
        step.linkLibrary(znoise.artifact("FastNoiseLite"));
    }

    // Add run step so 'zig build run' executes program after building
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Similar to the above, add test step for 'zig build test'
    const run_unit_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
