const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const module = b.addModule("zig-cli", .{
        .root_source_file = b.path("src/main.zig"),
    });

    const lib = b.addStaticLibrary(.{
        .name = "zig-cli",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    const simple = b.addExecutable(.{
        .target = target,
        .name = "simple",
        .root_source_file = b.path("examples/simple.zig"),
        .optimize = optimize,
    });
    simple.root_module.addImport("zig-cli", module);
    b.installArtifact(simple);
    b.default_step.dependOn(&simple.step);

    const short = b.addExecutable(.{
        .target = target,
        .name = "short",
        .root_source_file = b.path("examples/short.zig"),
        .optimize = optimize,
    });
    short.root_module.addImport("zig-cli", module);
    b.installArtifact(short);
    b.default_step.dependOn(&short.step);
}
